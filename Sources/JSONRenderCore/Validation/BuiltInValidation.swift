/// A validation function: the field value (`nil` is undefined) and the resolved arguments.
public typealias ValidationFunction =
    @Sendable (_ value: JSONValue?, _ args: [String: JSONValue?]) -> Bool

/// A catalog validator: the function and an optional description for the prompt.
public struct ValidationFunctionDefinition: Sendable {
    public var validate: ValidationFunction
    public var description: String?

    public init(description: String? = nil, validate: @escaping ValidationFunction) {
        self.validate = validate
        self.description = description
    }
}

/// The fourteen upstream validation functions (`validation.ts`
/// `builtInValidationFunctions`), with the same semantics.
///
/// Documented deviations:
/// - `pattern` uses Swift `Regex`, not a JavaScript `RegExp`. Simple classes, anchors and
///   quantifiers behave the same; lookbehind and named-group syntax can differ. A pattern
///   that does not compile fails the check, as upstream.
/// - `url` checks the WHATWG shape by hand (a scheme, and a host for the special schemes);
///   it is not a full WHATWG URL parser. The upstream fixtures decide the edge cases.
public enum BuiltInValidation {
    /// The names, in upstream order.
    public static let names: [String] = [
        "required", "email", "minLength", "maxLength", "pattern", "min", "max", "numeric",
        "url", "matches", "equalTo", "lessThan", "greaterThan", "requiredIf",
    ]

    /// The functions by name.
    public static let functions: [String: ValidationFunction] = [
        "required": { value, _ in isPresent(value) },
        "email": { value, _ in
            guard case .string(let text)? = value else { return false }
            return isEmail(text)
        },
        "minLength": { value, args in
            guard case .string(let text)? = value, case .number(let min)?? = args["min"] else {
                return false
            }
            return Double(text.utf16.count) >= min
        },
        "maxLength": { value, args in
            guard case .string(let text)? = value, case .number(let max)?? = args["max"] else {
                return false
            }
            return Double(text.utf16.count) <= max
        },
        "pattern": { value, args in
            guard case .string(let text)? = value, case .string(let pattern)?? = args["pattern"]
            else { return false }
            return matches(text, pattern: pattern)
        },
        "min": { value, args in
            guard case .number(let number)? = value, case .number(let min)?? = args["min"] else {
                return false
            }
            return number >= min
        },
        "max": { value, args in
            guard case .number(let number)? = value, case .number(let max)?? = args["max"] else {
                return false
            }
            return number <= max
        },
        "numeric": { value, _ in
            switch value {
            case .number(let number)?: return !number.isNaN
            case .string(let text)?:
                return !JSNumberParse.trim(text).isEmpty && !JSNumberParse.number(text).isNaN
            default: return false
            }
        },
        "url": { value, _ in
            guard case .string(let text)? = value else { return false }
            return isURL(text)
        },
        "matches": { value, args in JSONValue.strictEquals(value, args["other"] ?? nil) },
        "equalTo": { value, args in JSONValue.strictEquals(value, args["other"] ?? nil) },
        "lessThan": { value, args in compare(value, args["other"] ?? nil, lessThan: true) },
        "greaterThan": { value, args in compare(value, args["other"] ?? nil, lessThan: false) },
        "requiredIf": { value, args in
            guard let condition = args["field"] ?? nil, condition.isTruthy else { return true }
            return isPresent(value)
        },
    ]

    /// The fourteen prompt lines from upstream `schema.ts` (VALIDATION section), verbatim.
    public static let promptLines: [String] = [
        "  - required — value must be non-empty",
        "  - email — valid email format",
        "  - minLength — minimum string length (args: { \"min\": N })",
        "  - maxLength — maximum string length (args: { \"max\": N })",
        "  - pattern — match a regex (args: { \"pattern\": \"regex\" })",
        "  - min — minimum numeric value (args: { \"min\": N })",
        "  - max — maximum numeric value (args: { \"max\": N })",
        "  - numeric — value must be a number",
        "  - url — valid URL format",
        "  - matches — must equal another field (args: { \"other\": { \"$state\": \"/path\" } })",
        "  - equalTo — alias for matches (args: { \"other\": { \"$state\": \"/path\" } })",
        "  - lessThan — value must be less than another field (args: { \"other\": { \"$state\": \"/path\" } })",
        "  - greaterThan — value must be greater than another field (args: { \"other\": { \"$state\": \"/path\" } })",
        "  - requiredIf — required only when another field is truthy (args: { \"field\": { \"$state\": \"/path\" } })",
    ]

    // MARK: - Helpers

    /// `required`: not null or undefined; a string with non-whitespace; a non-empty array.
    static func isPresent(_ value: JSONValue?) -> Bool {
        switch value {
        case nil, .null?: false
        case .string(let text)?: !JSNumberParse.trim(text).isEmpty
        case .array(let items)?: !items.isEmpty
        default: true
        }
    }

    /// `/^[^\s@]+@[^\s@]+\.[^\s@]+$/`: one `@`, no whitespace, and a dot in the domain
    /// with at least one character on each side.
    static func isEmail(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        guard !scalars.contains(where: JSNumberParse.isWhitespace) else { return false }
        let parts = text.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let domain = Array(parts[1].unicodeScalars)
        guard domain.count >= 3 else { return false }
        return domain.indices.contains { index in
            domain[index] == "." && index > 0 && index < domain.count - 1
        }
    }

    /// `new RegExp(pattern).test(text)`: an unanchored search. A pattern that does not
    /// compile gives `false`.
    static func matches(_ text: String, pattern: String) -> Bool {
        guard let regex = try? Regex(pattern) else { return false }
        return (try? regex.firstMatch(in: text)) != nil
    }

    /// The URL check. See the type documentation.
    static func isURL(_ raw: String) -> Bool {
        let text = JSNumberParse.trim(raw)
        guard let colon = text.firstIndex(of: ":") else { return false }
        let scheme = text[text.startIndex..<colon]
        guard let first = scheme.unicodeScalars.first, isASCIILetter(first),
            scheme.unicodeScalars.allSatisfy({
                isASCIILetter($0) || ("0"..."9").contains($0) || $0 == "+" || $0 == "-"
                    || $0 == "."
            })
        else { return false }
        let rest = text[text.index(after: colon)...]
        guard !rest.unicodeScalars.contains(where: { $0 == " " }) else { return false }
        let special = ["http", "https", "ws", "wss", "ftp"]
        guard special.contains(scheme.lowercased()) else { return true }
        // Special schemes need a host: strip slashes, take up to the first / ? #.
        let afterSlashes = rest.drop(while: { $0 == "/" || $0 == "\\" })
        let authority = afterSlashes.prefix(while: { !"/?#\\".contains($0) })
        let hostAndPort = authority.split(separator: "@").last.map(String.init) ?? ""
        var host = Substring(hostAndPort)
        if let portColon = hostAndPort.lastIndex(of: ":"), !hostAndPort.hasSuffix("]") {
            let port = hostAndPort[hostAndPort.index(after: portColon)...]
            guard port.allSatisfy(\.isASCII), port.allSatisfy(\.isNumber) else { return false }
            if let number = Int(port), number > 65_535 { return false }
            host = hostAndPort[hostAndPort.startIndex..<portColon]
        }
        guard !host.isEmpty else { return false }
        let forbidden: Set<Character> = ["<", ">", "^", "|", "%", " "]
        return !host.contains(where: { forbidden.contains($0) })
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    /// `lessThan` / `greaterThan`: null, undefined and `""` fail; two numbers or two strings
    /// compare directly (strings by UTF-16 code units, as JavaScript); otherwise both sides
    /// are coerced with `Number()` and compared when neither is `NaN`.
    static func compare(_ value: JSONValue?, _ other: JSONValue?, lessThan: Bool) -> Bool {
        guard let value, let other, value != .null, other != .null, value != .string(""),
            other != .string("")
        else { return false }
        switch (value, other) {
        case (.number(let lhs), .number(let rhs)):
            return lessThan ? lhs < rhs : lhs > rhs
        case (.string(let lhs), .string(let rhs)):
            return lessThan
                ? lhs.utf16.lexicographicallyPrecedes(rhs.utf16)
                : rhs.utf16.lexicographicallyPrecedes(lhs.utf16)
        default:
            let lhs = JSNumberParse.number(of: value)
            let rhs = JSNumberParse.number(of: other)
            guard !lhs.isNaN, !rhs.isNaN else { return false }
            return lessThan ? lhs < rhs : lhs > rhs
        }
    }
}
