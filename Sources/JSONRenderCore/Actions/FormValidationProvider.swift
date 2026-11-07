/// The validation side of the `validateForm` built-in (upstream React `ValidationProvider`).
/// jr-1b's `FormValidator` conforms.
public protocol FormValidationProvider: Sendable {
    /// Validates every registered field against `state`.
    func validateAll(state: JSONValue) async -> FormValidationOutcome
}

/// What `validateForm` writes to state: `{ valid, errors }`, where `errors` maps a field
/// path to its messages and lists only failing fields.
public struct FormValidationOutcome: Sendable, Hashable {
    public var valid: Bool
    public var errors: [String: [String]]

    public init(valid: Bool, errors: [String: [String]] = [:]) {
        self.valid = valid
        self.errors = errors
    }

    /// `{ "valid": …, "errors": { "/path": ["message"] } }`.
    public var jsonValue: JSONValue {
        .object([
            "valid": .bool(valid),
            "errors": .object(errors.mapValues { .array($0.map(JSONValue.string)) }),
        ])
    }
}
