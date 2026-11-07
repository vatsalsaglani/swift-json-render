/// A JSON value as json-render sees it.
///
/// JavaScript `undefined` has no case here. Upstream "undefined" is modelled as `nil`
/// (`JSONValue?`), and `JSONValue.null` is JSON `null`. The two never collapse:
/// `{ "$state": "/missing", "eq": null }` is `false`, as it is upstream.
///
/// All numbers are `Double`, as in JavaScript.
public enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])
}

// MARK: - JavaScript semantics

extension JSONValue {
    /// JavaScript truthiness (`Boolean(value)`): `null`, `false`, `0`, `-0`, `NaN` and `""`
    /// are false. Arrays and objects are true, also when they are empty.
    public var isTruthy: Bool {
        switch self {
        case .null: false
        case .bool(let value): value
        case .number(let value): !(value == 0 || value.isNaN)
        case .string(let value): !value.isEmpty
        case .array, .object: true
        }
    }

    /// JavaScript `String(value)`: `"42"`, `"42.5"`, `"true"`, `"null"`, arrays joined
    /// by `","` (with `null` elements as `""`), objects as `"[object Object]"`.
    public var jsString: String {
        switch self {
        case .null: "null"
        case .bool(let value): value ? "true" : "false"
        case .number(let value): JSNumberFormat.string(value)
        case .string(let value): value
        case .array(let items):
            items.map { item in
                if case .null = item { return "" }
                return item.jsString
            }.joined(separator: ",")
        case .object: "[object Object]"
        }
    }

    /// JavaScript `===` for values that came from JSON.
    ///
    /// `nil` (undefined) equals only `nil`; `nil` never equals `.null`. `NaN` never equals
    /// anything. Arrays and objects compare by value: Swift has no object identity for JSON,
    /// so where upstream compares references this compares contents (documented deviation).
    public func strictEquals(_ other: JSONValue?) -> Bool {
        guard let other else { return false }
        switch (self, other) {
        case (.null, .null): return true
        case (.bool(let lhs), .bool(let rhs)): return lhs == rhs
        case (.number(let lhs), .number(let rhs)): return lhs == rhs
        case (.string(let lhs), .string(let rhs)): return lhs == rhs
        case (.array, .array), (.object, .object): return self == other
        default: return false
        }
    }

    /// `===` with `undefined` on either side.
    static func strictEquals(_ lhs: JSONValue?, _ rhs: JSONValue?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil): true
        case (let lhs?, _): lhs.strictEquals(rhs)
        case (nil, _?): false
        }
    }
}

// MARK: - Accessors

extension JSONValue {
    /// The member named `key` when the value is an object.
    public subscript(key: String) -> JSONValue? {
        guard case .object(let members) = self else { return nil }
        return members[key]
    }

    /// The element at `index` when the value is an array and the index is in range.
    public subscript(index: Int) -> JSONValue? {
        guard case .array(let items) = self, items.indices.contains(index) else { return nil }
        return items[index]
    }

    /// The string when the value is a string.
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    /// The number when the value is a number.
    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    /// The Boolean when the value is a Boolean.
    public var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    /// The members when the value is an object.
    public var objectValue: [String: JSONValue]? {
        if case .object(let members) = self { return members }
        return nil
    }

    /// The elements when the value is an array.
    public var arrayValue: [JSONValue]? {
        if case .array(let items) = self { return items }
        return nil
    }

    /// `true` for `.array` and `.object` (JavaScript `typeof value === "object"` minus `null`).
    var isContainer: Bool {
        switch self {
        case .array, .object: true
        default: false
        }
    }
}

// MARK: - Literals

extension JSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}

extension JSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
}

extension JSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .number(value) }
}

extension JSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}

extension JSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: JSONValue...) { self = .array(elements) }
}

extension JSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, JSONValue)...) {
        var members: [String: JSONValue] = [:]
        for (key, value) in elements { members[key] = value }
        self = .object(members)
    }
}

extension JSONValue: ExpressibleByNilLiteral {
    /// `nil` as a literal of type `JSONValue` is JSON `null`. An `Optional<JSONValue>`
    /// literal `nil` stays `Optional.none` (undefined).
    public init(nilLiteral: ()) { self = .null }
}

// MARK: - Codable

extension JSONValue: Codable {
    /// The deepest container nesting that decoding accepts (equal to
    /// `SpecLimits.defaultMaxDepth`). Decoding and the recursive operations on `JSONValue`
    /// use the stack; a cooperative-pool thread has a small stack (512 KiB), and a few
    /// hundred levels crash it. A deeper document throws `DecodingError.dataCorrupted`.
    public static let maxDecodeDepth = SpecLimits.defaultMaxDepth

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .number(value)
            return
        }
        if let value = try? container.decode(String.self) {
            self = .string(value)
            return
        }
        // Only containers remain. A container at coding-path depth `maxDecodeDepth` would be
        // nesting level `maxDecodeDepth + 1`.
        guard decoder.codingPath.count < JSONValue.maxDecodeDepth else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription:
                        "The JSON nests deeper than \(JSONValue.maxDecodeDepth) levels."))
        }
        // A type mismatch means "not this container kind"; any other error (for example
        // the depth limit further down) propagates.
        do {
            self = .array(try container.decode([JSONValue].self))
            return
        } catch let error as DecodingError {
            guard case .typeMismatch = error else { throw error }
        }
        do {
            self = .object(try container.decode([String: JSONValue].self))
            return
        } catch let error as DecodingError {
            guard case .typeMismatch = error else { throw error }
        }
        throw DecodingError.dataCorruptedError(
            in: container, debugDescription: "The value is not JSON.")
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .string(let value): try container.encode(value)
        case .array(let items): try container.encode(items)
        case .object(let members): try container.encode(members)
        }
    }
}

// MARK: - Debug

extension JSONValue: CustomDebugStringConvertible {
    /// A compact JSON-like rendering with sorted keys. Use it in tests and diagnostics only;
    /// never log it for user data (it contains values).
    public var debugDescription: String {
        switch self {
        case .null: "null"
        case .bool(let value): value ? "true" : "false"
        case .number(let value): JSNumberFormat.string(value)
        case .string(let value): JSONValue.quoted(value)
        case .array(let items): "[" + items.map(\.debugDescription).joined(separator: ",") + "]"
        case .object(let members):
            "{"
                + members.keys.sorted().map { key in
                    JSONValue.quoted(key) + ":" + (members[key]?.debugDescription ?? "null")
                }.joined(separator: ",") + "}"
        }
    }

    static func quoted(_ string: String) -> String {
        var result = "\""
        for scalar in string.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    result += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        return result + "\""
    }
}
