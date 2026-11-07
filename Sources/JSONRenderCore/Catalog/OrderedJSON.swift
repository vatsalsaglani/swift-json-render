/// A JSON value with ordered object members, for text that must match JavaScript
/// `JSON.stringify` byte for byte (the prompt examples and the user prompt).
///
/// `JSONValue` objects are dictionaries without order. Text built from them uses this type,
/// with an explicit member order where upstream has one and code-point order elsewhere.
indirect enum OrderedJSON: Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([OrderedJSON])
    case object([(String, OrderedJSON)])

    /// The deepest level converted from a `JSONValue`; deeper values become `null`
    /// (`JSONValue.maxDecodeDepth`).
    static let maxDepth = 64

    /// Converts a `JSONValue`; object members are sorted by key.
    init(_ value: JSONValue) {
        self.init(value, depth: 0)
    }

    private init(_ value: JSONValue, depth: Int) {
        guard depth < OrderedJSON.maxDepth else {
            self = .null
            return
        }
        switch value {
        case .null: self = .null
        case .bool(let flag): self = .bool(flag)
        case .number(let number): self = .number(number)
        case .string(let text): self = .string(text)
        case .array(let items): self = .array(items.map { OrderedJSON($0, depth: depth + 1) })
        case .object(let members):
            self = .object(
                members.keys.sorted().map {
                    ($0, OrderedJSON(members[$0] ?? .null, depth: depth + 1))
                })
        }
    }

    /// Converts back to a `JSONValue` (the order is lost).
    var jsonValue: JSONValue {
        switch self {
        case .null: .null
        case .bool(let flag): .bool(flag)
        case .number(let number): .number(number)
        case .string(let text): .string(text)
        case .array(let items): .array(items.map(\.jsonValue))
        case .object(let members):
            .object(Dictionary(members.map { ($0.0, $0.1.jsonValue) }, uniquingKeysWith: { $1 }))
        }
    }

    /// The member list when the value is an object.
    var members: [(String, OrderedJSON)]? {
        if case .object(let members) = self { return members }
        return nil
    }

    /// `JSON.stringify(value)`: compact, members in order.
    var stringified: String {
        var output = ""
        write(to: &output, indent: nil, level: 0)
        return output
    }

    /// `JSON.stringify(value, null, 2)`.
    var prettyStringified: String {
        var output = ""
        write(to: &output, indent: "  ", level: 0)
        return output
    }

    private func write(to output: inout String, indent: String?, level: Int) {
        switch self {
        case .null: output += "null"
        case .bool(let flag): output += flag ? "true" : "false"
        case .number(let number):
            output += number.isFinite ? JSNumberFormat.string(number) : "null"
        case .string(let text): output += OrderedJSON.quote(text)
        case .array(let items):
            writeContainer(
                to: &output, open: "[", close: "]", count: items.count, indent: indent,
                level: level
            ) { output, index in
                items[index].write(to: &output, indent: indent, level: level + 1)
            }
        case .object(let members):
            writeContainer(
                to: &output, open: "{", close: "}", count: members.count, indent: indent,
                level: level
            ) { output, index in
                output += OrderedJSON.quote(members[index].0)
                output += indent == nil ? ":" : ": "
                members[index].1.write(to: &output, indent: indent, level: level + 1)
            }
        }
    }

    private func writeContainer(
        to output: inout String, open: String, close: String, count: Int, indent: String?,
        level: Int, item: (inout String, Int) -> Void
    ) {
        output += open
        guard count > 0 else {
            output += close
            return
        }
        for index in 0..<count {
            if index > 0 { output += "," }
            if let indent { output += "\n" + String(repeating: indent, count: level + 1) }
            item(&output, index)
        }
        if let indent { output += "\n" + String(repeating: indent, count: level) }
        output += close
    }

    /// `JSON.stringify` string quoting: `\"`, `\\`, the short escapes `\b \f \n \r \t`, and
    /// `\u00xx` for other control characters. Nothing else is escaped.
    static func quote(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\u{08}": result += "\\b"
            case "\u{0C}": result += "\\f"
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
