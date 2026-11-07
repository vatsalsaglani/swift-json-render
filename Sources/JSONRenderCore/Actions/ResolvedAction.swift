/// An action binding with its params resolved (upstream `ResolvedAction`).
public struct ResolvedAction: Sendable, Hashable {
    public var action: String
    /// Resolved params. `nil` values are undefined (the key was present but resolved to
    /// nothing, for example `$item` outside a repeat).
    public var params: [String: JSONValue?]
    /// The confirmation with `${path}` interpolated from state.
    public var confirm: ActionConfirm?
    public var onSuccess: ActionOnSuccess?
    public var onError: ActionOnError?

    public init(
        action: String, params: [String: JSONValue?] = [:], confirm: ActionConfirm? = nil,
        onSuccess: ActionOnSuccess? = nil, onError: ActionOnError? = nil
    ) {
        self.action = action
        self.params = params
        self.confirm = confirm
        self.onSuccess = onSuccess
        self.onError = onError
    }
}

extension ActionBinding {
    /// Resolves the binding the way the React renderer and `resolveAction` do together:
    /// each param through `resolveActionParam` (so `$item` gives an absolute path and
    /// `$index` the row index), and `confirm.title` / `confirm.message` through upstream
    /// `interpolateString` (`${path}` reads state only, never the repeat item).
    public func resolved(in context: PropResolutionContext) -> (
        ResolvedAction, [ResolutionWarning]
    ) {
        var resolver = PropResolver(context: context)
        var resolvedParams: [String: JSONValue?] = [:]
        for (key, value) in params ?? [:] {
            resolvedParams[key] = .some(resolver.resolveActionParam(value))
        }
        var resolvedConfirm = confirm
        if let confirm {
            resolvedConfirm?.title = Template.interpolateState(confirm.title, state: context.state)
            resolvedConfirm?.message = Template.interpolateState(
                confirm.message, state: context.state)
        }
        let action = ResolvedAction(
            action: action, params: resolvedParams, confirm: resolvedConfirm,
            onSuccess: onSuccess, onError: onError)
        return (action, resolver.warnings)
    }
}

extension ActionBinding {
    /// Upstream `interpolateString`: replaces every `${path}` with the state value at `path`
    /// (`""` for a missing or `null` value).
    public static func interpolate(_ template: String, state: JSONValue) -> String {
        Template.interpolateState(template, state: state)
    }
}
