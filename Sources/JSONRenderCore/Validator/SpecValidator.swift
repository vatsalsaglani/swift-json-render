public import Foundation

/// The upstream structural pass (`spec-validator.ts` `validateSpec`).
///
/// Documented deviations:
/// - Elements are checked in id order (code-point), not insertion order, so issue order is
///   stable across runs. The set of issues is the same.
/// - The repeat-path walk stops below `SpecLimits.maxDepth` ancestors (upstream recurses
///   without a cap). Deeper elements are reported by the `depth_exceeded` extension check.
public enum SpecValidator {
    /// The upstream issues for `spec`.
    public static func upstreamIssues(
        _ spec: Spec, checkOrphans: Bool = false, limits: SpecLimits = .default
    ) -> [SpecIssue] {
        var issues: [SpecIssue] = []
        guard !spec.root.isEmpty else {
            return [
                SpecIssue(
                    severity: .error, code: .missingRoot,
                    message: "Spec has no root element defined.")
            ]
        }
        if spec.elements[spec.root] == nil {
            issues.append(
                SpecIssue(
                    severity: .error, code: .rootNotFound,
                    message: "Root element \"\(spec.root)\" not found in elements map."))
        }
        guard !spec.elements.isEmpty else {
            issues.append(
                SpecIssue(severity: .error, code: .emptySpec, message: "Spec has no elements."))
            return issues
        }
        let keys = spec.elements.keys.sorted()
        for key in keys {
            guard let element = spec.elements[key] else { continue }
            elementIssues(key, element, spec: spec, into: &issues)
        }
        var walk = RepeatWalk(spec: spec, maxDepth: limits.maxDepth)
        if spec.elements[spec.root] != nil {
            walk.visit(spec.root, base: nil, sampleAvailable: true, ancestors: [])
        }
        for key in keys where !walk.visited.contains(key) {
            walk.visit(key, base: nil, sampleAvailable: true, ancestors: [])
        }
        issues += walk.issues
        if checkOrphans {
            let reachable = reachableIDs(spec)
            for key in keys where !reachable.contains(key) {
                issues.append(
                    SpecIssue(
                        severity: .warning, code: .orphanedElement,
                        message: "Element \"\(key)\" is not reachable from root \"\(spec.root)\".",
                        elementKey: key))
            }
        }
        return issues
    }

    private static func elementIssues(
        _ key: String, _ element: UIElement, spec: Spec, into issues: inout [SpecIssue]
    ) {
        for child in element.children ?? [] where spec.elements[child] == nil {
            issues.append(
                SpecIssue(
                    severity: .error, code: .missingChild,
                    message:
                        "Element \"\(key)\" references child \"\(child)\" which does not exist in the elements map.",
                    elementKey: key))
        }
        let slots = element.slots ?? [:]
        for name in slots.keys.sorted() {
            for child in slots[name] ?? [] where spec.elements[child] == nil {
                issues.append(
                    SpecIssue(
                        severity: .error, code: .missingChild,
                        message:
                            "Element \"\(key)\" references child \"\(child)\" in slot \"\(name)\" which does not exist in the elements map.",
                        elementKey: key))
            }
        }
        if element.repeat != nil, (element.children ?? []).isEmpty {
            issues.append(
                SpecIssue(
                    severity: .error, code: .repeatWithoutChildren,
                    message:
                        "Element \"\(key)\" has \"repeat\" but no children. The repeated template must be a child element: add a child that renders one item (it may read fields with {\"$item\": \"field\"}).",
                    elementKey: key))
        }
        if let visible = element.visible, !visible.isStrictlyValid {
            let shown = OrderedJSON(visible.jsonValue).stringified
            issues.append(
                SpecIssue(
                    severity: .error, code: .invalidVisible,
                    message:
                        "Element \"\(key)\" has an invalid \"visible\" condition: \(shown). Valid forms: true, false, {\"$state\":\"/path\",\"eq\":value}, {\"$item\":\"field\",\"eq\":value}, {\"$index\":true,\"eq\":n}, an array of those (AND), or {\"$and\":[...]} / {\"$or\":[...]}. Use exactly one of $state, $item, or $index per condition object.",
                    elementKey: key))
        }
        let misplaced: [(String, SpecIssue.Code)] = [
            ("visible", .visibleInProps), ("on", .onInProps), ("repeat", .repeatInProps),
            ("watch", .watchInProps),
        ]
        for (field, code) in misplaced where element.props[field] != nil {
            issues.append(
                SpecIssue(
                    severity: .error, code: code,
                    message:
                        "Element \"\(key)\" has \"\(field)\" inside \"props\". It should be a top-level field on the element (sibling of type/props/children).",
                    elementKey: key))
        }
    }

    /// Upstream `validateRepeatPaths`.
    private struct RepeatWalk {
        let spec: Spec
        let maxDepth: Int
        var visited: Set<String> = []
        var contexts: Set<String> = []
        var issues: [SpecIssue] = []

        init(spec: Spec, maxDepth: Int) {
            self.spec = spec
            self.maxDepth = maxDepth
        }

        mutating func visit(
            _ key: String, base: JSONPointer?, sampleAvailable: Bool, ancestors: Set<String>
        ) {
            guard !ancestors.contains(key), ancestors.count <= maxDepth,
                let element = spec.elements[key]
            else { return }
            visited.insert(key)
            let context = "\(key)\u{0}\(base?.description ?? "")\u{0}\(sampleAvailable)"
            guard contexts.insert(context).inserted else { return }
            var childBase = base
            var childSample = sampleAvailable
            if let config = element.repeat {
                let display: String =
                    switch config.statePath {
                    case .absolute(let path): path
                    case .item(let field):
                        OrderedJSON.object([("$item", .string(field))]).stringified
                    }
                if let statePath = RepeatScope.resolveStatePath(config.statePath, enclosing: base) {
                    let isAbsolute: Bool =
                        if case .absolute = config.statePath { true } else { false }
                    let canCheck = spec.state != nil && (isAbsolute || sampleAvailable)
                    let value = canCheck ? spec.state?.value(at: statePath) : nil
                    var isArray = false
                    var nonEmpty = false
                    if case .array(let items)? = value {
                        isArray = true
                        nonEmpty = !items.isEmpty
                    }
                    if canCheck, !isArray {
                        let found =
                            value.map { " has a \(SpecValidator.typeName($0)) there" }
                            ?? " has no value there"
                        issues.append(
                            SpecIssue(
                                severity: .error, code: .repeatStateMismatch,
                                message:
                                    "Element \"\(key)\" repeats over \"\(statePath)\" but state\(found). Repeat statePath must reference an array in state; add sample items to state at that path.",
                                elementKey: key))
                    }
                    childBase = RepeatScope.itemStatePath(statePath, index: 0)
                    childSample = canCheck && nonEmpty
                } else {
                    issues.append(
                        SpecIssue(
                            severity: .error, code: .repeatItemOutsideScope,
                            message:
                                "Element \"\(key)\" uses relative repeat statePath \(display) outside a repeat scope.",
                            elementKey: key))
                    childBase = nil
                    childSample = false
                }
            }
            var next = ancestors
            next.insert(key)
            for child in element.children ?? [] {
                visit(child, base: childBase, sampleAvailable: childSample, ancestors: next)
            }
            let slots = element.slots ?? [:]
            for name in slots.keys.sorted() {
                for child in slots[name] ?? [] {
                    visit(child, base: base, sampleAvailable: sampleAvailable, ancestors: next)
                }
            }
        }
    }

    /// JavaScript `typeof` for a JSON value.
    static func typeName(_ value: JSONValue) -> String {
        switch value {
        case .null, .array, .object: "object"
        case .bool: "boolean"
        case .number: "number"
        case .string: "string"
        }
    }

    /// Ids reachable from the root over children and slots (iterative).
    static func reachableIDs(_ spec: Spec) -> Set<String> {
        var reachable: Set<String> = []
        guard spec.elements[spec.root] != nil else { return reachable }
        var stack = [spec.root]
        while let id = stack.popLast() {
            guard reachable.insert(id).inserted, let element = spec.elements[id] else { continue }
            let slots = element.slots ?? [:]
            for child in (element.children ?? []) + slots.keys.sorted().flatMap({ slots[$0] ?? [] })
            where spec.elements[child] != nil {
                stack.append(child)
            }
        }
        return reachable
    }
}

extension Catalog {
    /// Validates a spec: the upstream pass, then the Swift extension checks (unknown
    /// component, prop schema, caps and cycles), then the catalog rules. Each extension
    /// group can be turned off in `options`; `ValidateSpecOptions.upstream()` gives the
    /// upstream result only.
    public func validate(
        _ spec: Spec, options: ValidateSpecOptions = ValidateSpecOptions(),
        limits: SpecLimits = .default
    ) -> ValidationReport {
        var issues = SpecValidator.upstreamIssues(
            spec, checkOrphans: options.checkOrphans, limits: limits)
        let keys = spec.elements.keys.sorted()
        for key in keys {
            guard let element = spec.elements[key] else { continue }
            guard let definition = component(named: element.type) else {
                if options.checkComponents, !components.isEmpty {
                    issues.append(
                        SpecIssue(
                            severity: .error, code: .unknownComponent,
                            message:
                                "Element \"\(key)\" has type \"\(element.type)\", which is not in the catalog.",
                            elementKey: key))
                }
                continue
            }
            guard options.checkProps else { continue }
            var props = element.props
            for field in ["visible", "on", "repeat", "watch"] { props[field] = nil }
            for problem in definition.props.validate(.object(props)) {
                issues.append(
                    SpecIssue(
                        severity: .error, code: .invalidProps,
                        message:
                            "Element \"\(key)\" (\(element.type)) prop \"\(problem.path)\": \(problem.message)",
                        elementKey: key))
            }
        }
        if options.checkLimits { issues += limitIssues(spec, keys: keys, limits: limits) }
        if options.checkRules {
            for name in ruleOrder {
                guard let rule = rules[name] else { continue }
                issues += rule(spec, spec.state).map { issue in
                    var issue = issue
                    if issue.code == .customRule, issue.rule == nil { issue.rule = name }
                    return issue
                }
            }
        }
        return ValidationReport(issues: issues)
    }

    /// Decodes and validates. A document over `limits.maxBytes` gives a report with one
    /// `spec_too_large` error instead of throwing; other decode errors throw.
    public func validate(
        data: Data, options: ValidateSpecOptions = ValidateSpecOptions(),
        limits: SpecLimits = .default
    ) throws(SpecDecodeError) -> ValidationReport {
        guard data.count <= limits.maxBytes else {
            return ValidationReport(issues: [
                SpecIssue(
                    severity: .error, code: .specTooLarge,
                    message: "The spec is \(data.count) bytes; the limit is \(limits.maxBytes).")
            ])
        }
        return validate(
            try Spec.decode(data, limits: limits).spec, options: options, limits: limits)
    }

    private func limitIssues(_ spec: Spec, keys: [String], limits: SpecLimits) -> [SpecIssue] {
        var issues: [SpecIssue] = []
        if spec.elements.count > limits.maxElements {
            issues.append(
                SpecIssue(
                    severity: .error, code: .tooManyElements,
                    message:
                        "The spec has \(spec.elements.count) elements; the limit is \(limits.maxElements)."
                ))
        }
        let plan = RenderPlan(spec: spec, limits: limits)
        for cycle in plan.cycles {
            issues.append(
                SpecIssue(
                    severity: .error, code: .cycle,
                    message:
                        "Elements form a cycle: \((cycle + [cycle[0]]).joined(separator: " -> ")).",
                    elementKey: cycle.first))
        }
        for id in plan.truncatedAtDepth.sorted() {
            issues.append(
                SpecIssue(
                    severity: .error, code: .depthExceeded,
                    message:
                        "Element \"\(id)\" is nested deeper than \(limits.maxDepth) levels.",
                    elementKey: id))
        }
        for key in keys {
            guard case .absolute(let raw)? = spec.elements[key]?.repeat?.statePath,
                case .array(let rows)? = spec.state?.value(at: JSONPointer(lenient: raw)),
                rows.count > limits.maxRepeatRows
            else { continue }
            issues.append(
                SpecIssue(
                    severity: .warning, code: .tooManyRepeatRows,
                    message:
                        "Element \"\(key)\" repeats over \(rows.count) rows; only the first \(limits.maxRepeatRows) render.",
                    elementKey: key))
        }
        return issues
    }
}
