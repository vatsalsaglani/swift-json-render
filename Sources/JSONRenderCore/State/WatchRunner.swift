/// Runs an element's `watch` bindings when watched state changes (upstream React
/// `renderer.tsx` watch effect, without React).
///
/// - The state at subscription is the baseline; nothing fires for it.
/// - For each later snapshot, a path fires only when its value changed
///   (`JSONValue.strictEquals`, so `nil` and `null` differ and objects compare by value).
/// - Paths are visited in sorted order; each path's bindings run one after another. Each
///   binding resolves its params against the store's snapshot at the moment it fires, so
///   it sees the writes of the bindings before it.
/// - A binding that throws stops the current round (upstream logs and stops the loop).
/// - `run` returns when its task is cancelled. Cancellation is checked before each binding,
///   so a binding that is running finishes first.
public struct WatchRunner: Sendable {
    public let store: StateStore
    public let dispatcher: ActionDispatcher

    public init(store: StateStore, dispatcher: ActionDispatcher) {
        self.store = store
        self.dispatcher = dispatcher
    }

    /// Subscribes to the store and runs until cancelled.
    public func run(
        elementID: String, watch: [String: [ActionBinding]],
        context: @Sendable @escaping (StateSnapshot) -> PropResolutionContext
    ) async {
        await run(
            elementID: elementID, watch: watch, subscription: await store.subscribe(),
            context: context)
    }

    /// Runs on a subscription the caller took earlier, so the baseline is the state at that
    /// moment (for example when the element appeared).
    public func run(
        elementID: String, watch: [String: [ActionBinding]], subscription: StateSubscription,
        context: @Sendable @escaping (StateSnapshot) -> PropResolutionContext
    ) async {
        let paths = watch.keys.sorted()
        guard !paths.isEmpty else { return }
        let pointers = paths.map { try? JSONPointer($0) }
        func values(_ snapshot: StateSnapshot) -> [JSONValue?] {
            pointers.map { pointer in pointer.flatMap { snapshot.state.value(at: $0) } }
        }
        var previous = values(subscription.current)
        for await snapshot in subscription.updates {
            if Task.isCancelled { return }
            let current = values(snapshot)
            let before = previous
            previous = current
            round: for (index, path) in paths.enumerated()
            where !JSONValue.strictEquals(current[index], before[index]) {
                for binding in watch[path] ?? [] {
                    if Task.isCancelled { return }
                    let live = await store.snapshot
                    do {
                        try await dispatcher.dispatch(
                            binding, elementID: elementID, context: context(live))
                    } catch {
                        break round
                    }
                }
            }
        }
    }
}
