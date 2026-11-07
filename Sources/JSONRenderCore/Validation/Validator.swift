/// The result of one check (upstream `ValidationCheckResult`).
public struct ValidationCheckResult: Sendable, Hashable {
    public var type: String
    public var valid: Bool
    public var message: String
    /// `true` when no built-in or custom function has this name. The check then passes, as
    /// upstream ("don't fail on unknown functions"); the flag replaces upstream's console
    /// warning.
    public var unknownFunction: Bool
    /// Set when the built-in `pattern` check was refused by `PatternGuard` (the check then
    /// fails without running the regex).
    public var patternRefusal: PatternGuard.Refusal?

    /// `true` when `PatternGuard` refused the `pattern` check.
    public var patternRefused: Bool { patternRefusal != nil }

    public init(
        type: String, valid: Bool, message: String, unknownFunction: Bool = false,
        patternRefusal: PatternGuard.Refusal? = nil
    ) {
        self.type = type
        self.valid = valid
        self.message = message
        self.unknownFunction = unknownFunction
        self.patternRefusal = patternRefusal
    }
}

/// The result of all checks of one field (upstream `ValidationResult`).
public struct ValidationResult: Sendable, Hashable {
    public var valid: Bool
    /// The messages of the failing checks, in check order.
    public var errors: [String]
    public var checks: [ValidationCheckResult]

    public init(valid: Bool, errors: [String], checks: [ValidationCheckResult]) {
        self.valid = valid
        self.errors = errors
        self.checks = checks
    }
}

/// Runs validation configurations (upstream `runValidationCheck` and `runValidation`).
public enum Validator {
    /// The error text for a `pattern` check that `PatternGuard` refused. The spec's own
    /// message would claim the value is wrong, which was never checked.
    public static let patternRefusedMessage = "This pattern cannot be checked"

    /// Runs one check. Arguments resolve as prop expressions against `state` (no repeat
    /// scope). A built-in name wins over a custom function with the same name, as upstream.
    public static func runCheck(
        _ check: ValidationCheck, value: JSONValue?, state: JSONValue,
        custom: [String: ValidationFunction] = [:]
    ) -> ValidationCheckResult {
        var resolver = PropResolver(context: PropResolutionContext(state: state))
        var args: [String: JSONValue?] = [:]
        for (key, raw) in check.args ?? [:] {
            args[key] = .some(resolver.resolveValue(raw))
        }
        guard let function = BuiltInValidation.functions[check.type] ?? custom[check.type] else {
            return ValidationCheckResult(
                type: check.type, valid: true, message: check.message, unknownFunction: true)
        }
        var refusal: PatternGuard.Refusal?
        if check.type == "pattern", case .string(let text)? = value,
            case .string(let pattern)?? = args["pattern"]
        {
            refusal = PatternGuard.refusal(pattern: pattern, value: text)
        }
        return ValidationCheckResult(
            type: check.type, valid: refusal == nil && function(value, args),
            message: check.message, patternRefusal: refusal)
    }

    /// Runs every check of `config`. When `enabled` is present and evaluates to false
    /// against `state`, the result is valid with no checks.
    public static func run(
        _ config: ValidationConfig, value: JSONValue?, state: JSONValue,
        custom: [String: ValidationFunction] = [:]
    ) -> ValidationResult {
        if let enabled = config.enabled,
            !VisibilityEvaluator.evaluate(enabled, in: VisibilityContext(state: state))
        {
            return ValidationResult(valid: true, errors: [], checks: [])
        }
        var checks: [ValidationCheckResult] = []
        var errors: [String] = []
        for check in config.checks ?? [] {
            let result = runCheck(check, value: value, state: state, custom: custom)
            checks.append(result)
            if !result.valid {
                errors.append(result.patternRefused ? patternRefusedMessage : result.message)
            }
        }
        return ValidationResult(valid: errors.isEmpty, errors: errors, checks: checks)
    }
}
