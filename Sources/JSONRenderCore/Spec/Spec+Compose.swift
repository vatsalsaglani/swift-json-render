/// Why `Spec.composing` refused a child spec.
public enum ComposeError: Error, Sendable, Hashable {
    /// The prefix is empty, or holds `/`, `~` or `__proto__`.
    case invalidPrefix(String)
    /// The parent element does not exist.
    case parentNotFound(String)
    /// A prefixed child id already exists in the parent spec.
    case idConflict(String)
    /// The parent state already has a member named by the prefix.
    case stateConflict(String)
    /// The parent state is not an object, so the child state cannot be merged.
    case parentStateNotObject
}

extension Spec {
    /// Inserts `child` under the element `parentID` (VPLAN 6, nesting).
    ///
    /// - Every child id becomes `"<prefix>:<id>"`; `children` and `slots` follow.
    /// - The child state moves under `/<prefix>` in the parent state. Every absolute state
    ///   path in the child moves with it: `$state`, `$bindState`, `${/…}` in `$template`,
    ///   `$state` references in conditions and operands, absolute `repeat.statePath`, `watch`
    ///   keys, `onSuccess` / `onError` `set` keys, and the `statePath` / `clearStatePath`
    ///   params of the state built-ins. `$item`, `$bindItem`, `$index` and relative repeat
    ///   paths stay relative.
    /// - Not rewritten: bare `${name}` template names (they read the repeat item first, so
    ///   their meaning depends on the row) and the `${path}` text of `confirm`.
    /// - The child root is appended to the parent's `children`, or to `slots[slot]`.
    public func composing(
        _ child: Spec, into parentID: String, slot: String? = nil, prefix: String
    ) throws(ComposeError) -> Spec {
        guard !prefix.isEmpty, !prefix.contains("/"), !prefix.contains("~"),
            prefix != JSONPointer.forbiddenToken
        else { throw .invalidPrefix(prefix) }
        guard elements[parentID] != nil else { throw .parentNotFound(parentID) }

        let rewriter = ComposeRewriter(prefix: prefix)
        var result = self
        for id in child.elements.keys.sorted() {
            let newID = rewriter.id(id)
            if result.elements[newID] != nil { throw .idConflict(newID) }
        }
        if let childState = child.state {
            var parentState = result.state ?? .object([:])
            guard case .object(var members) = parentState else { throw .parentStateNotObject }
            if members[prefix] != nil { throw .stateConflict(prefix) }
            members[prefix] = childState
            parentState = .object(members)
            result.state = parentState
        }
        for (id, element) in child.elements {
            result.elements[rewriter.id(id)] = rewriter.element(element)
        }
        let childRoot = rewriter.id(child.root)
        guard var parent = result.elements[parentID] else { throw .parentNotFound(parentID) }
        if let slot {
            parent.slots = parent.slots ?? [:]
            parent.slots?[slot, default: []].append(childRoot)
        } else {
            parent.children = (parent.children ?? []) + [childRoot]
        }
        result.elements[parentID] = parent
        return result
    }
}

/// The id and state-path rewriting for `Spec.composing`.
struct ComposeRewriter {
    let prefix: String

    static let stateBuiltIns: Set<String> = [
        "setState", "pushState", "removeState", "toggleState", "incrementState", "validateForm",
    ]

    func id(_ id: String) -> String { "\(prefix):\(id)" }

    func path(_ path: String) -> String {
        JSONPointer(tokens: [prefix] + JSONPointer(lenient: path).tokens).description
    }

    func element(_ element: UIElement) -> UIElement {
        var copy = element
        copy.props = element.props.mapValues(value)
        copy.children = element.children?.map(id)
        copy.slots = element.slots?.mapValues { $0.map(id) }
        if let visible = element.visible {
            copy.visible = VisibilityCondition(json: value(visible.jsonValue))
        }
        if let config = element.repeat, case .absolute(let statePath) = config.statePath {
            copy.repeat = RepeatConfig(statePath: .absolute(path(statePath)), key: config.key)
        }
        copy.on = element.on?.mapValues { $0.map(binding) }
        if let watch = element.watch {
            var rewritten: [String: [ActionBinding]] = [:]
            for (key, bindings) in watch { rewritten[path(key)] = bindings.map(binding) }
            copy.watch = rewritten
        }
        return copy
    }

    func binding(_ binding: ActionBinding) -> ActionBinding {
        var copy = binding
        if var params = binding.params {
            params = params.mapValues(value)
            if ComposeRewriter.stateBuiltIns.contains(binding.action) {
                for key in ["statePath", "clearStatePath"] {
                    if case .string(let statePath)? = params[key], !statePath.isEmpty {
                        params[key] = .string(path(statePath))
                    }
                }
            }
            copy.params = params
        }
        switch binding.onSuccess {
        case .set(let values)?: copy.onSuccess = .set(setMap(values))
        case .action(let name, let params)?:
            copy.onSuccess = .action(name, params: params?.mapValues(value))
        default: break
        }
        switch binding.onError {
        case .set(let values)?: copy.onError = .set(setMap(values))
        case .action(let name, let params)?:
            copy.onError = .action(name, params: params?.mapValues(value))
        default: break
        }
        return copy
    }

    private func setMap(_ values: [String: JSONValue]) -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        for (key, item) in values { result[path(key)] = value(item) }
        return result
    }

    /// Rewrites absolute state references inside a raw prop or condition value.
    func value(_ value: JSONValue) -> JSONValue {
        switch value {
        case .array(let items):
            return .array(items.map(self.value))
        case .object(let members):
            var result: [String: JSONValue] = [:]
            for (key, member) in members {
                switch (key, member) {
                case ("$state", .string(let statePath)), ("$bindState", .string(let statePath)):
                    result[key] = .string(path(statePath))
                case ("$template", .string(let template)):
                    result[key] = .string(self.template(template))
                default:
                    result[key] = self.value(member)
                }
            }
            return .object(result)
        default:
            return value
        }
    }

    private func template(_ template: String) -> String {
        Template.interpolate(template) { rawPath in
            rawPath.hasPrefix("/") ? "${\(path(rawPath))}" : "${\(rawPath)}"
        }
    }
}
