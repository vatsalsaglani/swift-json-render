/// The subset of zod that the upstream prompt and schema formatters understand.
///
/// jr-1a seed: the data shape and the builders only. jr-1b adds `formatted()`,
/// `jsonSchema(strict:)`, `exampleValue()` and `validate(_:at:)`.
public struct PropSchema: Sendable, Hashable {
    public indirect enum Kind: Sendable, Hashable {
        case string
        case number
        case boolean
        case any
        case literal(JSONValue)
        case `enum`([String])
        case array(PropSchema)
        case object([Field])
        case record(PropSchema)
        case union([PropSchema])
    }

    /// One field of an object schema. Field order is significant (prompt and schema output).
    public struct Field: Sendable, Hashable {
        public var name: String
        public var schema: PropSchema
        public var description: String?

        public init(name: String, schema: PropSchema, description: String? = nil) {
            self.name = name
            self.schema = schema
            self.description = description
        }
    }

    public var kind: Kind
    /// zod `.optional()`: the value may be absent. (Named `isOptional` because the builder
    /// method `optional()` uses the base name.)
    public var isOptional: Bool
    /// zod `.nullable()`: the value may be `null`.
    public var isNullable: Bool
    public var description: String?

    public init(
        kind: Kind, isOptional: Bool = false, isNullable: Bool = false, description: String? = nil
    ) {
        self.kind = kind
        self.isOptional = isOptional
        self.isNullable = isNullable
        self.description = description
    }

    public static let string = PropSchema(kind: .string)
    public static let number = PropSchema(kind: .number)
    public static let boolean = PropSchema(kind: .boolean)
    public static let any = PropSchema(kind: .any)

    public static func object(_ fields: [Field]) -> PropSchema { PropSchema(kind: .object(fields)) }
    public static func `enum`(_ values: [String]) -> PropSchema { PropSchema(kind: .enum(values)) }
    public static func array(_ element: PropSchema) -> PropSchema {
        PropSchema(kind: .array(element))
    }
    public static func record(_ value: PropSchema) -> PropSchema {
        PropSchema(kind: .record(value))
    }
    public static func literal(_ value: JSONValue) -> PropSchema {
        PropSchema(kind: .literal(value))
    }
    public static func union(_ options: [PropSchema]) -> PropSchema {
        PropSchema(kind: .union(options))
    }

    /// A copy that also accepts `null`.
    public func nullable() -> PropSchema {
        var copy = self
        copy.isNullable = true
        return copy
    }

    /// A copy that may be absent.
    public func optional() -> PropSchema {
        var copy = self
        copy.isOptional = true
        return copy
    }

    /// A copy with a description.
    public func described(_ text: String) -> PropSchema {
        var copy = self
        copy.description = text
        return copy
    }
}
