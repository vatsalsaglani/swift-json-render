internal import Foundation

/// Runs action bindings (upstream React `ActionProvider.execute` and core `executeAction`).
///
/// Order per dispatch:
/// 1. Resolve the binding (params, `confirm` text).
/// 2. `observer.dispatched`.
/// 3. A built-in: ask the host to confirm when `confirm` is present, run it, settle.
///    **Documented deviation:** upstream runs built-ins before its confirm check, so a
///    `confirm` on `setState` is ignored there. Here every action honours `confirm`.
/// 4. Otherwise look up the catalog handler; none → settle `.noHandler` and return.
/// 5. `confirm` → the host. Declined → settle `.cancelled` and return without throwing
///    (upstream rejects with "Action cancelled").
/// 6. Run the handler, then `onSuccess` (`navigate` | `set` | `action`). An error, also
///    from `onSuccess`, runs `onError` (`set`, with `"$error.message"` replaced | `action`);
///    without `onError` the error is rethrown.
/// 7. `observer.settled`.
///
/// Built-ins do not run `onSuccess` / `onError`, as upstream. `onSuccess.set` and
/// `onError.set` write all their paths in one commit (upstream writes them one by one).
public struct ActionDispatcher: Sendable {
    public let catalog: Catalog
    public let store: StateStore
    public let host: any ActionHost
    public let validation: (any FormValidationProvider)?
    public let observer: (any ActionObserver)?

    public init(
        catalog: Catalog, store: StateStore, host: any ActionHost,
        validation: (any FormValidationProvider)? = nil, observer: (any ActionObserver)? = nil
    ) {
        self.catalog = catalog
        self.store = store
        self.host = host
        self.validation = validation
        self.observer = observer
    }

    /// Resolves `binding` in `context` and runs it. `elementID` is for observers only.
    public func dispatch(
        _ binding: ActionBinding, elementID: String?, context: PropResolutionContext
    )
        async throws
    {
        let (resolved, _) = binding.resolved(in: context)
        let id = UUID().uuidString
        let clock = ContinuousClock()
        let start = clock.now
        observer?.dispatched(
            ActionDispatchInfo(id: id, name: resolved.action, elementID: elementID, at: Date()))
        func settle(ok: Bool, _ outcome: ActionSettleInfo.Outcome) {
            observer?.settled(
                ActionSettleInfo(
                    id: id, name: resolved.action, elementID: elementID, ok: ok, outcome: outcome,
                    at: Date(), duration: clock.now - start))
        }
        do {
            let outcome = try await perform(resolved, elementID: elementID, context: context)
            settle(ok: outcome != .cancelled, outcome)
        } catch {
            settle(ok: false, .failed)
            throw error
        }
    }

    private func perform(
        _ resolved: ResolvedAction, elementID: String?, context: PropResolutionContext
    ) async throws -> ActionSettleInfo.Outcome {
        if let builtIn = BuiltInAction(rawValue: resolved.action) {
            if let confirm = resolved.confirm,
                !(await host.confirm(confirm, action: resolved.action))
            {
                return .cancelled
            }
            return await run(builtIn, params: resolved.params)
        }
        guard let handler = catalog.actions[resolved.action]?.handler else {
            return .noHandler
        }
        if let confirm = resolved.confirm, !(await host.confirm(confirm, action: resolved.action)) {
            return .cancelled
        }
        try await execute(handler, resolved, elementID: elementID, context: context)
        return .completed
    }

    private func run(_ action: BuiltInAction, params: [String: JSONValue?]) async
        -> ActionSettleInfo.Outcome
    {
        guard action == .validateForm else {
            await store.modify { state in
                BuiltInAction.changes(for: action, params: params, state: state)
            }
            return .completed
        }
        guard let validation else { return .unavailable }
        let state = await store.snapshot.state
        let outcome = await validation.validateAll(state: state)
        let path =
            BuiltInAction.statePath(params["statePath"]) ?? BuiltInAction.defaultValidationPath
        await store.set(path, outcome.jsonValue)
        return .completed
    }

    private func execute(
        _ handler: ActionHandler, _ resolved: ResolvedAction, elementID: String?,
        context: PropResolutionContext
    ) async throws {
        do {
            _ = try await handler(resolved.params, host)
            switch resolved.onSuccess {
            case .navigate(let path)?:
                await host.navigate(path)
            case .set(let values)?:
                await store.update(ActionDispatcher.writes(values) { $0 })
            case .action(let name, let params)?:
                try await dispatch(
                    ActionBinding(action: name, params: params), elementID: elementID,
                    context: await followUpContext(context))
            case nil:
                break
            }
        } catch {
            switch resolved.onError {
            case .set(let values)?:
                let message = ActionFailure.message(of: error)
                await store.update(
                    ActionDispatcher.writes(values) { value in
                        value == .string("$error.message") ? .string(message) : value
                    })
            case .action(let name, let params)?:
                try await dispatch(
                    ActionBinding(action: name, params: params), elementID: elementID,
                    context: await followUpContext(context))
            case nil:
                throw error
            }
        }
    }

    /// Upstream follow-up actions resolve against the current state, outside any repeat.
    private func followUpContext(_ context: PropResolutionContext) async -> PropResolutionContext {
        PropResolutionContext(
            state: await store.snapshot.state, functions: context.functions,
            directives: context.directives)
    }

    /// `set` maps in key order; keys that are not usable pointers are skipped.
    private static func writes(
        _ values: [String: JSONValue], _ transform: (JSONValue) -> JSONValue
    ) -> [(JSONPointer, JSONValue)] {
        values.keys.sorted().compactMap { key in
            guard let pointer = try? JSONPointer(key), !pointer.isRoot, let value = values[key]
            else { return nil }
            return (pointer, transform(value))
        }
    }
}
