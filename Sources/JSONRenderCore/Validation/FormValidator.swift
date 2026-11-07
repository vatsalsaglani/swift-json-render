/// The form validation provider (upstream React `ValidationProvider`): fields register their
/// configuration by state path, and `validateForm` validates them all.
///
/// One instance per rendered spec. Field values are read from the state passed in, never
/// stored here.
public actor FormValidator: FormValidationProvider {
    private let custom: [String: ValidationFunction]
    private var fields: [JSONPointer: ValidationConfig] = [:]
    private var results: [JSONPointer: ValidationResult] = [:]

    /// `custom` holds the catalog validators. Built-in names win over custom names.
    public init(custom: [String: ValidationFunction] = [:]) {
        self.custom = custom
    }

    /// Registers or replaces the configuration of the field at `path`.
    public func register(path: JSONPointer, config: ValidationConfig) {
        fields[path] = config
    }

    /// Removes the field at `path` and its last result.
    public func unregister(path: JSONPointer) {
        fields[path] = nil
        results[path] = nil
    }

    /// The registered field paths.
    public var registeredPaths: Set<JSONPointer> { Set(fields.keys) }

    /// The last result of the field at `path`, if it was validated.
    public func lastResult(path: JSONPointer) -> ValidationResult? { results[path] }

    /// Validates one field against `state`. `nil` when the path is not registered.
    public func validate(path: JSONPointer, state: JSONValue) -> ValidationResult? {
        guard let config = fields[path] else { return nil }
        let result = Validator.run(
            config, value: state.value(at: path), state: state, custom: custom)
        results[path] = result
        return result
    }

    /// Validates every registered field. `errors` lists only the failing fields, keyed by
    /// the canonical path string.
    public func validateAll(state: JSONValue) -> FormValidationOutcome {
        var errors: [String: [String]] = [:]
        for path in fields.keys {
            guard let result = validate(path: path, state: state), !result.valid else { continue }
            errors[path.description] = result.errors
        }
        return FormValidationOutcome(valid: errors.isEmpty, errors: errors)
    }
}
