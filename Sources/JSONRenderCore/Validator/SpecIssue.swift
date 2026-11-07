/// One problem found in a spec (upstream `SpecIssue`). Messages carry element ids, paths
/// and type names, never prop or state values (except the upstream `invalid_visible`
/// message, which quotes the condition as upstream does).
public struct SpecIssue: Sendable, Hashable {
    public enum Severity: String, Sendable, Hashable {
        case error, warning
    }

    public enum Code: String, Sendable, Hashable, CaseIterable {
        // Upstream codes; the raw values are the upstream strings.
        case missingRoot = "missing_root"
        case rootNotFound = "root_not_found"
        case emptySpec = "empty_spec"
        case missingChild = "missing_child"
        case invalidVisible = "invalid_visible"
        case visibleInProps = "visible_in_props"
        case onInProps = "on_in_props"
        case repeatInProps = "repeat_in_props"
        case watchInProps = "watch_in_props"
        case repeatWithoutChildren = "repeat_without_children"
        case repeatItemOutsideScope = "repeat_item_outside_scope"
        case repeatStateMismatch = "repeat_state_mismatch"
        case orphanedElement = "orphaned_element"
        // Swift extensions.
        case unknownComponent = "unknown_component"
        case invalidProps = "invalid_props"
        case cycle = "cycle"
        case depthExceeded = "depth_exceeded"
        case tooManyElements = "too_many_elements"
        case tooManyRepeatRows = "too_many_repeat_rows"
        case specTooLarge = "spec_too_large"
        /// An issue from a catalog rule (`Catalog.rule`); `rule` names it.
        case customRule = "custom_rule"

        /// `true` for the thirteen upstream codes.
        public var isUpstream: Bool {
            switch self {
            case .unknownComponent, .invalidProps, .cycle, .depthExceeded,
                .tooManyElements, .tooManyRepeatRows, .specTooLarge, .customRule:
                false
            default:
                true
            }
        }
    }

    public var severity: Severity
    public var code: Code
    public var message: String
    public var elementKey: String?
    /// The catalog rule that produced the issue (`customRule` only).
    public var rule: String?

    public init(
        severity: Severity, code: Code, message: String, elementKey: String? = nil,
        rule: String? = nil
    ) {
        self.severity = severity
        self.code = code
        self.message = message
        self.elementKey = elementKey
        self.rule = rule
    }
}

/// Options for `Catalog.validate`.
public struct ValidateSpecOptions: Sendable, Hashable {
    /// Upstream `checkOrphans`: warn about elements not reachable from the root.
    public var checkOrphans: Bool
    /// Report element types the catalog does not define (skipped for an empty catalog).
    public var checkComponents: Bool
    /// Check props against the component schema.
    public var checkProps: Bool
    /// Check the `SpecLimits` caps and cycles.
    public var checkLimits: Bool
    /// Run the catalog rules.
    public var checkRules: Bool

    public init(
        checkOrphans: Bool = false, checkComponents: Bool = true, checkProps: Bool = true,
        checkLimits: Bool = true, checkRules: Bool = true
    ) {
        self.checkOrphans = checkOrphans
        self.checkComponents = checkComponents
        self.checkProps = checkProps
        self.checkLimits = checkLimits
        self.checkRules = checkRules
    }

    /// Only the upstream pass (`validateSpec`), as the parity fixtures run it.
    public static func upstream(checkOrphans: Bool = false) -> ValidateSpecOptions {
        ValidateSpecOptions(
            checkOrphans: checkOrphans, checkComponents: false, checkProps: false,
            checkLimits: false, checkRules: false)
    }
}

/// The result of `Catalog.validate` (upstream `SpecValidationIssues`).
public struct ValidationReport: Sendable, Hashable {
    /// `true` when there is no error (warnings are allowed).
    public var valid: Bool
    public var issues: [SpecIssue]

    public init(issues: [SpecIssue]) {
        self.issues = issues
        self.valid = !issues.contains { $0.severity == .error }
    }

    public var errors: [SpecIssue] { issues.filter { $0.severity == .error } }
    public var warnings: [SpecIssue] { issues.filter { $0.severity == .warning } }

    /// Upstream `formatSpecIssues`: the error messages for a repair prompt, or `""`.
    public func formatted() -> String {
        let errors = errors
        guard !errors.isEmpty else { return "" }
        return
            (["The generated UI spec has the following errors:"]
            + errors.map { "- \($0.message)" }).joined(separator: "\n")
    }
}

/// One auto-fix (upstream `SpecFix`).
public struct SpecFix: Sendable, Hashable {
    public var message: String
    /// `true` when the fix changes what renders (pruning a dangling reference).
    public var lossy: Bool

    public init(message: String, lossy: Bool) {
        self.message = message
        self.lossy = lossy
    }
}
