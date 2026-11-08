internal import JSONRenderCore

/// Init-time candidate checks (upstream `validateCandidate` and the id rules in
/// `experimental_composeSpec`). A bad candidate fails before any request.
enum CandidateValidation {
    /// Expression keys a candidate may use. As upstream: no repeat scope, no computed
    /// functions, no templates, no custom directives.
    static let allowedExpressionKeys: Set<String> = ["$state", "$bindState", "$and", "$or"]

    /// Ids the composer uses itself.
    static let reservedIDs: Set<String> = ["finish", "unavailable", "omit"]

    static func check(_ candidates: [CompositionCandidate], catalog: Catalog)
        throws(CompositionError)
    {
        var ids: Set<String> = []
        for candidate in candidates {
            let id = candidate.id
            guard isValidID(id) else {
                throw .invalidCandidate(id: id, reason: "The id is not a valid identifier.")
            }
            guard !reservedIDs.contains(id), !isNodeID(id) else {
                throw .invalidCandidate(id: id, reason: "The id is reserved.")
            }
            guard ids.insert(id).inserted else {
                throw .invalidCandidate(id: id, reason: "The id is a duplicate.")
            }
            guard candidate.maxUses >= 1 else {
                throw .invalidCandidate(id: id, reason: "maxUses must be at least one.")
            }
            try checkElement(candidate.element, id: id, catalog: catalog)
        }
        guard candidates.contains(where: \.root) else { throw .noRootCandidate }
    }

    /// Upstream `/^[a-zA-Z][\w-]*$/`.
    static func isValidID(_ id: String) -> Bool {
        guard let first = id.unicodeScalars.first, isASCIILetter(first) else { return false }
        return id.unicodeScalars.allSatisfy { scalar in
            isASCIILetter(scalar) || ("0"..."9").contains(scalar) || scalar == "_"
                || scalar == "-"
        }
    }

    /// `node_<digits>`: the ids the composer gives to elements.
    static func isNodeID(_ id: String) -> Bool {
        guard id.hasPrefix("node_") else { return false }
        let rest = id.dropFirst(5)
        return !rest.isEmpty && rest.unicodeScalars.allSatisfy { ("0"..."9").contains($0) }
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }

    private static func checkElement(_ element: UIElement, id: String, catalog: Catalog)
        throws(CompositionError)
    {
        guard let definition = catalog.component(named: element.type) else {
            throw .invalidCandidate(
                id: id, reason: "The type \"\(element.type)\" is not in the catalog.")
        }
        guard element.repeat == nil else {
            throw .invalidCandidate(id: id, reason: "A candidate cannot use repeat.")
        }
        guard element.watch == nil else {
            throw .invalidCandidate(id: id, reason: "A candidate cannot use watch.")
        }
        if case .object(let fields) = definition.props.kind {
            let known = Set(fields.map(\.name))
            if let extra = element.props.keys.sorted().first(where: { !known.contains($0) }) {
                throw .invalidCandidate(
                    id: id, reason: "The prop \"\(extra)\" is not in the \(element.type) schema.")
            }
        }
        try checkExpressions(.object(element.props), id: id)
        if let problem = definition.props.validate(.object(element.props)).first {
            throw .invalidCandidate(
                id: id, reason: "The prop \"\(problem.path)\" is invalid: \(problem.message)")
        }
        if let visible = element.visible {
            if case .invalid = visible {
                throw .invalidCandidate(id: id, reason: "The visibility condition is invalid.")
            }
            try checkExpressions(visible.jsonValue, id: id)
        }
        for event in (element.on ?? [:]).keys.sorted() {
            guard definition.events.contains(event) else {
                throw .invalidCandidate(
                    id: id, reason: "The event \"\(event)\" is not on \(element.type).")
            }
            for binding in element.on?[event] ?? [] {
                try checkBinding(binding, id: id, catalog: catalog)
            }
        }
    }

    private static func checkBinding(_ binding: ActionBinding, id: String, catalog: Catalog)
        throws(CompositionError)
    {
        try checkAction(binding.action, params: binding.params, id: id, catalog: catalog)
        switch binding.onSuccess {
        case nil: break
        case .action(let name, let params)?:
            try checkAction(name, params: params, id: id, catalog: catalog)
        case .navigate?, .set?:
            throw .invalidCandidate(
                id: id, reason: "Composition callbacks must reference catalog actions.")
        }
        switch binding.onError {
        case nil: break
        case .action(let name, let params)?:
            try checkAction(name, params: params, id: id, catalog: catalog)
        case .set?:
            throw .invalidCandidate(
                id: id, reason: "Composition callbacks must reference catalog actions.")
        }
    }

    private static func checkAction(
        _ name: String, params: [String: JSONValue]?, id: String, catalog: Catalog
    ) throws(CompositionError) {
        let definition = catalog.actions[name]
        let builtIn = (catalog.builtInActions + catalog.extensionActions).contains {
            $0.name == name
        }
        guard definition != nil || builtIn else {
            throw .invalidCandidate(id: id, reason: "The action \"\(name)\" is not in the catalog.")
        }
        try checkExpressions(.object(params ?? [:]), id: id)
        if let definition, let problem = definition.params.validate(.object(params ?? [:])).first {
            throw .invalidCandidate(
                id: id,
                reason:
                    "The action \"\(name)\" param \"\(problem.path)\" is invalid: \(problem.message)"
            )
        }
    }

    /// Upstream `checkExpressions`: only `$state`, `$bindState`, `$and`, `$or`; state
    /// expressions must hold a path string.
    private static func checkExpressions(_ value: JSONValue, id: String)
        throws(CompositionError)
    {
        switch value {
        case .array(let items):
            for item in items { try checkExpressions(item, id: id) }
        case .object(let members):
            for key in members.keys.sorted() {
                guard let child = members[key] else { continue }
                if key.hasPrefix("$") {
                    guard allowedExpressionKeys.contains(key) else {
                        throw .invalidCandidate(
                            id: id, reason: "The expression \(key) is not supported.")
                    }
                    if key == "$state" || key == "$bindState", child.stringValue == nil {
                        throw .invalidCandidate(id: id, reason: "\(key) must be a state path.")
                    }
                }
                try checkExpressions(child, id: id)
            }
        default:
            break
        }
    }
}
