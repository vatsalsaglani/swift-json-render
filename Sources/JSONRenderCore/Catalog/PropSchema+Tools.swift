/// A prop value that does not match its schema. Carries the prop path and the expected
/// shape, never the value.
public struct PropIssue: Sendable, Hashable {
    /// A dotted path such as `items.0.label`; `""` for the value itself.
    public var path: String
    public var message: String

    public init(path: String, message: String) {
        self.path = path
        self.message = message
    }
}

extension PropSchema {
    /// `true` when the value may be absent or `null` (zod `.optional()` or `.nullable()`).
    /// Upstream marks such object fields with `?` and leaves them out of examples.
    var isOptionalLike: Bool { isOptional || isNullable }

    // MARK: - formatZodType

    /// Upstream `formatZodType` (`schema.ts`): `"string"`, `"\"a\" | \"b\""`,
    /// `"Array<string>"`, `"{ title: string, subtitle?: string }"`,
    /// `"Record<string, unknown>"`. `.any` formats as `"unknown"`.
    public func formatted() -> String {
        switch kind {
        case .string: return "string"
        case .number: return "number"
        case .boolean: return "boolean"
        case .any: return "unknown"
        case .literal(let value): return OrderedJSON(value).stringified
        case .enum(let values): return values.map { "\"\($0)\"" }.joined(separator: " | ")
        case .array(let element): return "Array<\(element.formatted())>"
        case .object(let fields):
            let body = fields.map { field in
                "\(field.name)\(field.schema.isOptionalLike ? "?" : ""): \(field.schema.formatted())"
            }.joined(separator: ", ")
            return "{ \(body) }"
        case .record(let value): return "Record<string, \(value.formatted())>"
        case .union(let options): return options.map { $0.formatted() }.joined(separator: " | ")
        }
    }

    // MARK: - zodToJsonSchema

    /// Upstream `zodToJsonSchema` (`schema.ts`), both branches.
    ///
    /// Strict mode (LLM structured outputs): every object lists all properties in
    /// `required`, optional ones become `anyOf [schema, { type: null }]`, every object has
    /// `additionalProperties: false`, and records and `.any` become an opaque empty object.
    /// `JSONValue` objects have no key order; use `jsonSchemaText(strict:)` for bytes in the
    /// upstream key order (type, properties, required, additionalProperties).
    public func jsonSchema(strict: Bool) -> JSONValue {
        orderedJSONSchema(strict: strict).jsonValue
    }

    /// `JSON.stringify(jsonSchema(strict:))` with upstream key order.
    public func jsonSchemaText(strict: Bool) -> String {
        orderedJSONSchema(strict: strict).stringified
    }

    func orderedJSONSchema(strict: Bool) -> OrderedJSON {
        switch kind {
        case .string: return .object([("type", .string("string"))])
        case .number: return .object([("type", .string("number"))])
        case .boolean: return .object([("type", .string("boolean"))])
        case .literal(let value): return .object([("const", OrderedJSON(value))])
        case .enum(let values): return .object([("enum", .array(values.map(OrderedJSON.string)))])
        case .array(let element):
            return .object([
                ("type", .string("array")), ("items", element.orderedJSONSchema(strict: strict)),
            ])
        case .object(let fields):
            var properties: [(String, OrderedJSON)] = []
            var required: [OrderedJSON] = []
            for field in fields {
                let inner = field.schema.orderedJSONSchema(strict: strict)
                if strict {
                    required.append(.string(field.name))
                    properties.append(
                        (
                            field.name,
                            field.schema.isOptionalLike
                                ? .object([
                                    (
                                        "anyOf",
                                        .array([inner, .object([("type", .string("null"))])])
                                    )
                                ]) : inner
                        ))
                } else {
                    properties.append((field.name, inner))
                    if !field.schema.isOptionalLike { required.append(.string(field.name)) }
                }
            }
            var members: [(String, OrderedJSON)] = [
                ("type", .string("object")), ("properties", .object(properties)),
            ]
            if !required.isEmpty { members.append(("required", .array(required))) }
            members.append(("additionalProperties", .bool(false)))
            return .object(members)
        case .record(let value):
            if strict { return PropSchema.opaqueObject }
            return .object([
                ("type", .string("object")),
                ("additionalProperties", value.orderedJSONSchema(strict: false)),
            ])
        case .union(let options):
            return .object([("anyOf", .array(options.map { $0.orderedJSONSchema(strict: strict) }))]
            )
        case .any:
            return strict ? PropSchema.opaqueObject : .object([])
        }
    }

    static let opaqueObject: OrderedJSON = .object([
        ("type", .string("object")), ("properties", .object([])), ("required", .array([])),
        ("additionalProperties", .bool(false)),
    ])

    // MARK: - generateExampleValue

    /// Upstream `generateExampleValue`: `"example"`, `0`, `true`, the first enum value, `[]`,
    /// an object of its required fields only, the first union option, `"..."` for records
    /// and `.any`.
    ///
    /// Deviation: a literal gives its value. Upstream reads `def.value`, which zod 4 does not
    /// set, so a required literal prop drops out of the upstream example.
    public func exampleValue() -> JSONValue {
        orderedExample().jsonValue
    }

    func orderedExample() -> OrderedJSON {
        switch kind {
        case .string: return .string("example")
        case .number: return .number(0)
        case .boolean: return .bool(true)
        case .literal(let value): return OrderedJSON(value)
        case .enum(let values): return .string(values.first ?? "example")
        case .array: return .array([])
        case .object(let fields):
            return .object(
                fields.filter { !$0.schema.isOptionalLike }.map {
                    ($0.name, $0.schema.orderedExample())
                })
        case .union(let options): return options.first?.orderedExample() ?? .string("...")
        case .record, .any: return .string("...")
        }
    }

    /// Upstream `findFirstStringProp`: the first required `string` field of an object schema.
    func firstRequiredStringField() -> String? {
        guard case .object(let fields) = kind else { return nil }
        return fields.first { !$0.schema.isOptionalLike && $0.schema.kind == .string }?.name
    }

    /// The field names of an object schema, in order (empty for other kinds).
    var fieldNames: [String] {
        guard case .object(let fields) = kind else { return [] }
        return fields.map(\.name)
    }

    // MARK: - Validation

    /// Checks a raw prop value against the schema. Used by `Catalog.validate` for the
    /// `invalid_props` extension check.
    ///
    /// A value that is an expression (an object with a key that starts with `$`, such as
    /// `{ "$state": "/x" }`) is accepted at any level: it resolves at render time. Unknown
    /// object keys are accepted (zod strips them). An absent value passes when the schema is
    /// optional **or nullable**: zod requires a nullable key to be present, but upstream never
    /// checks per-component props, and its catalogs mark most props nullable; strict presence
    /// would reject almost every real spec. Renderers treat absent and `null` alike.
    public func validate(_ value: JSONValue?, at path: String = "") -> [PropIssue] {
        validate(value, at: path, depth: 0)
    }

    /// The deepest value level `validate` descends; deeper values are accepted unchecked
    /// (`JSONValue.maxDecodeDepth`).
    static let maxValidationDepth = 64

    private func validate(_ value: JSONValue?, at path: String, depth: Int) -> [PropIssue] {
        guard depth < PropSchema.maxValidationDepth else { return [] }
        guard let value else {
            return isOptionalLike ? [] : [PropIssue(path: path, message: "Required.")]
        }
        if value == .null {
            return isNullable ? [] : [PropIssue(path: path, message: "Expected \(formatted()).")]
        }
        if case .object(let members) = value, members.keys.contains(where: { $0.hasPrefix("$") }) {
            return []
        }
        let mismatch = [PropIssue(path: path, message: "Expected \(formatted()).")]
        switch kind {
        case .any:
            return []
        case .string:
            return value.stringValue == nil ? mismatch : []
        case .number:
            return value.numberValue == nil ? mismatch : []
        case .boolean:
            return value.boolValue == nil ? mismatch : []
        case .literal(let expected):
            return value == expected ? [] : mismatch
        case .enum(let values):
            guard case .string(let text) = value, values.contains(text) else { return mismatch }
            return []
        case .array(let element):
            guard case .array(let items) = value else { return mismatch }
            return items.enumerated().flatMap { index, item in
                element.validate(item, at: PropSchema.join(path, String(index)), depth: depth + 1)
            }
        case .object(let fields):
            guard case .object(let members) = value else { return mismatch }
            return fields.flatMap { field in
                field.schema.validate(
                    members[field.name], at: PropSchema.join(path, field.name), depth: depth + 1)
            }
        case .record(let valueSchema):
            guard case .object(let members) = value else { return mismatch }
            return members.keys.sorted().flatMap { key in
                valueSchema.validate(members[key], at: PropSchema.join(path, key), depth: depth + 1)
            }
        case .union(let options):
            return options.contains { $0.validate(value, at: path, depth: depth + 1).isEmpty }
                ? [] : mismatch
        }
    }

    private static func join(_ path: String, _ component: String) -> String {
        path.isEmpty ? component : path + "." + component
    }
}
