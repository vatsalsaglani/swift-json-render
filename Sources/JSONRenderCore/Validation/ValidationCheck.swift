/// One validation check (upstream `ValidationCheck`): a function name, optional arguments
/// (which may hold expressions such as `{ "$state": "/other" }`), and the error message.
public struct ValidationCheck: Sendable, Hashable {
    /// A built-in name (see `BuiltInValidation`) or a catalog validator name.
    public var type: String
    public var args: [String: JSONValue]?
    public var message: String

    public init(type: String, args: [String: JSONValue]? = nil, message: String) {
        self.type = type
        self.args = args
        self.message = message
    }
}

/// When a field validates (upstream `validateOn`).
public enum ValidateOn: String, Sendable, Hashable, Codable, CaseIterable {
    case change, blur, submit
}

/// The validation configuration of one field (upstream `ValidationConfig`).
public struct ValidationConfig: Sendable, Hashable {
    public var checks: [ValidationCheck]?
    public var validateOn: ValidateOn?
    /// When present and false for the current state, the field is valid with no checks run.
    public var enabled: VisibilityCondition?

    public init(
        checks: [ValidationCheck]? = nil, validateOn: ValidateOn? = nil,
        enabled: VisibilityCondition? = nil
    ) {
        self.checks = checks
        self.validateOn = validateOn
        self.enabled = enabled
    }
}

// MARK: - Upstream `check.*` helpers

extension ValidationCheck {
    /// `check.required`.
    public static func required(_ message: String = "This field is required") -> ValidationCheck {
        ValidationCheck(type: "required", message: message)
    }

    /// `check.email`.
    public static func email(_ message: String = "Invalid email address") -> ValidationCheck {
        ValidationCheck(type: "email", message: message)
    }

    /// `check.minLength`.
    public static func minLength(_ min: Double, _ message: String? = nil) -> ValidationCheck {
        ValidationCheck(
            type: "minLength", args: ["min": .number(min)],
            message: message ?? "Must be at least \(JSNumberFormat.string(min)) characters")
    }

    /// `check.maxLength`.
    public static func maxLength(_ max: Double, _ message: String? = nil) -> ValidationCheck {
        ValidationCheck(
            type: "maxLength", args: ["max": .number(max)],
            message: message ?? "Must be at most \(JSNumberFormat.string(max)) characters")
    }

    /// `check.pattern`.
    public static func pattern(_ pattern: String, _ message: String = "Invalid format")
        -> ValidationCheck
    {
        ValidationCheck(type: "pattern", args: ["pattern": .string(pattern)], message: message)
    }

    /// `check.min`.
    public static func min(_ min: Double, _ message: String? = nil) -> ValidationCheck {
        ValidationCheck(
            type: "min", args: ["min": .number(min)],
            message: message ?? "Must be at least \(JSNumberFormat.string(min))")
    }

    /// `check.max`.
    public static func max(_ max: Double, _ message: String? = nil) -> ValidationCheck {
        ValidationCheck(
            type: "max", args: ["max": .number(max)],
            message: message ?? "Must be at most \(JSNumberFormat.string(max))")
    }

    /// `check.url`.
    public static func url(_ message: String = "Invalid URL") -> ValidationCheck {
        ValidationCheck(type: "url", message: message)
    }

    /// `check.numeric`.
    public static func numeric(_ message: String = "Must be a number") -> ValidationCheck {
        ValidationCheck(type: "numeric", message: message)
    }

    /// `check.matches`: equal to the value at `otherPath`.
    public static func matches(_ otherPath: String, _ message: String = "Fields must match")
        -> ValidationCheck
    {
        ValidationCheck(type: "matches", args: stateArg("other", otherPath), message: message)
    }

    /// `check.equalTo`: alias of `matches`.
    public static func equalTo(_ otherPath: String, _ message: String = "Fields must match")
        -> ValidationCheck
    {
        ValidationCheck(type: "equalTo", args: stateArg("other", otherPath), message: message)
    }

    /// `check.lessThan`.
    public static func lessThan(_ otherPath: String, _ message: String? = nil) -> ValidationCheck {
        ValidationCheck(
            type: "lessThan", args: stateArg("other", otherPath),
            message: message ?? "Must be less than the compared field")
    }

    /// `check.greaterThan`.
    public static func greaterThan(_ otherPath: String, _ message: String? = nil)
        -> ValidationCheck
    {
        ValidationCheck(
            type: "greaterThan", args: stateArg("other", otherPath),
            message: message ?? "Must be greater than the compared field")
    }

    /// `check.requiredIf`: required while the value at `fieldPath` is truthy.
    public static func requiredIf(_ fieldPath: String, _ message: String = "This field is required")
        -> ValidationCheck
    {
        ValidationCheck(type: "requiredIf", args: stateArg("field", fieldPath), message: message)
    }

    private static func stateArg(_ name: String, _ path: String) -> [String: JSONValue] {
        [name: .object(["$state": .string(path)])]
    }
}

// MARK: - JSON conversion

extension ValidationCheck {
    /// Builds a check from JSON. Throws `.shape` when `type` or `message` is not a string.
    public init(json: JSONValue) throws(SpecDecodeError) {
        guard case .object(let members) = json, case .string(let type)? = members["type"],
            case .string(let message)? = members["message"]
        else {
            throw .shape("A validation check needs string \"type\" and \"message\".")
        }
        self.type = type
        self.message = message
        switch members["args"] {
        case nil, .null?: args = nil
        case .object(let values)?: args = values
        default: throw .shape("A validation check has \"args\" that is not an object.")
        }
    }

    /// The JSON form.
    public var jsonValue: JSONValue {
        var members: [String: JSONValue] = ["type": .string(type), "message": .string(message)]
        if let args { members["args"] = .object(args) }
        return .object(members)
    }
}

extension ValidationConfig {
    /// Builds a configuration from JSON. Unknown keys are ignored.
    public init(json: JSONValue) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("A validation config is not an object.")
        }
        switch members["checks"] {
        case nil, .null?:
            checks = nil
        case .array(let items)?:
            var parsed: [ValidationCheck] = []
            for item in items { parsed.append(try ValidationCheck(json: item)) }
            checks = parsed
        default:
            throw .shape("A validation config has \"checks\" that is not an array.")
        }
        switch members["validateOn"] {
        case nil, .null?: validateOn = nil
        case .string(let raw)?:
            guard let mode = ValidateOn(rawValue: raw) else {
                throw .shape("A validation config has an unknown \"validateOn\".")
            }
            validateOn = mode
        default: throw .shape("A validation config has a non-string \"validateOn\".")
        }
        enabled = members["enabled"].map(VisibilityCondition.init(json:))
    }

    /// The JSON form.
    public var jsonValue: JSONValue {
        var members: [String: JSONValue] = [:]
        if let checks { members["checks"] = .array(checks.map(\.jsonValue)) }
        if let validateOn { members["validateOn"] = .string(validateOn.rawValue) }
        if let enabled { members["enabled"] = enabled.jsonValue }
        return .object(members)
    }
}

extension ValidationCheck: Codable {
    public init(from decoder: any Decoder) throws {
        let json = try JSONValue(from: decoder)
        do {
            try self.init(json: json)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: error.message))
        }
    }

    public func encode(to encoder: any Encoder) throws { try jsonValue.encode(to: encoder) }
}

extension ValidationConfig: Codable {
    public init(from decoder: any Decoder) throws {
        let json = try JSONValue(from: decoder)
        do {
            try self.init(json: json)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: error.message))
        }
    }

    public func encode(to encoder: any Encoder) throws { try jsonValue.encode(to: encoder) }
}
