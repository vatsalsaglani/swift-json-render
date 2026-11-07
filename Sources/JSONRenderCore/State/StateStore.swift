/// The state model of one rendered spec (upstream `createStateStore`).
///
/// - Writes use the upstream path semantics (`JSONValue.set`, `remove`).
/// - A write that changes nothing commits nothing and notifies nobody. Swift deviation:
///   the no-op check compares values; upstream compares references, so setting an equal
///   but new object notifies upstream and does not notify here.
/// - A refused write (root pointer, `__proto__`, an index past the array end) commits
///   nothing; intermediates it would have created are discarded.
/// - `snapshots()` and `subscribe()` give each subscriber its own stream. A stream ends
///   when the store is released.
public actor StateStore {
    private var state: JSONValue
    private var version: UInt64 = 0
    private var lastChanged: Set<JSONPointer> = []
    private var subscribers: [Int: AsyncStream<StateSnapshot>.Continuation] = [:]
    private var nextSubscriberID = 0

    /// `nil` and non-object values start with `{}`.
    public init(initial: JSONValue? = nil) {
        if case .object? = initial, let initial {
            state = initial
        } else {
            state = .object([:])
        }
    }

    deinit {
        for continuation in subscribers.values {
            continuation.finish()
        }
    }

    /// The current snapshot.
    public var snapshot: StateSnapshot {
        StateSnapshot(version: version, state: state, changed: lastChanged)
    }

    /// The value at `pointer`, or `nil` when absent.
    public func get(_ pointer: JSONPointer) -> JSONValue? {
        state.value(at: pointer)
    }

    /// Writes `value` at `pointer`. A no-op when the value is already there.
    public func set(_ pointer: JSONPointer, _ value: JSONValue) {
        update([(pointer, value)])
    }

    /// Removes the value at `pointer`. A no-op when nothing is there.
    public func remove(_ pointer: JSONPointer) {
        apply([(pointer, nil)])
    }

    /// Applies every change in order as one commit with one snapshot. Changes that write
    /// an equal value or are refused are skipped. Returns `true` when something changed.
    @discardableResult
    public func update(_ changes: [(JSONPointer, JSONValue)]) -> Bool {
        apply(changes.map { ($0.0, Optional($0.1)) })
    }

    /// Reads the current state and applies the changes `build` returns, as one commit,
    /// without suspension between the read and the write. A `nil` value removes the path.
    /// The built-in actions use it for read-modify-write.
    @discardableResult
    func modify(_ build: @Sendable (JSONValue) -> [(JSONPointer, JSONValue?)]) -> Bool {
        apply(build(state))
    }

    @discardableResult
    private func apply(_ changes: [(JSONPointer, JSONValue?)]) -> Bool {
        var next = state
        var changed: Set<JSONPointer> = []
        for (pointer, value) in changes {
            var attempt = next
            if let value {
                if next.value(at: pointer) == value { continue }
                guard attempt.set(value, at: pointer) else { continue }
            } else {
                guard attempt.remove(at: pointer) else { continue }
            }
            next = attempt
            changed.insert(pointer)
        }
        guard !changed.isEmpty else { return false }
        commit(next, changed: changed)
        return true
    }

    /// Replaces the whole state (Reset View, stream flush). A non-object becomes `{}`.
    public func replaceAll(_ newState: JSONValue) {
        let next: JSONValue
        if case .object = newState { next = newState } else { next = .object([:]) }
        guard next != state else { return }
        commit(next, changed: [.root])
    }

    /// A new stream of snapshots. It yields the current snapshot first, then one per
    /// commit. With the default policy a slow reader sees only the newest snapshot (so a
    /// commit right after subscribing can replace the first element; use `subscribe()`
    /// when the starting value matters).
    public func snapshots(
        bufferingPolicy: AsyncStream<StateSnapshot>.Continuation.BufferingPolicy =
            .bufferingNewest(1)
    ) -> AsyncStream<StateSnapshot> {
        let (current, stream, continuation) = makeSubscription(bufferingPolicy)
        continuation.yield(current)
        return stream
    }

    /// The current snapshot and a stream of the commits after it, taken atomically. Use it
    /// when the starting value matters (for example a watch baseline).
    public func subscribe(
        bufferingPolicy: AsyncStream<StateSnapshot>.Continuation.BufferingPolicy =
            .bufferingNewest(1)
    ) -> StateSubscription {
        let (current, stream, _) = makeSubscription(bufferingPolicy)
        return StateSubscription(current: current, updates: stream)
    }

    private func makeSubscription(
        _ bufferingPolicy: AsyncStream<StateSnapshot>.Continuation.BufferingPolicy
    ) -> (StateSnapshot, AsyncStream<StateSnapshot>, AsyncStream<StateSnapshot>.Continuation) {
        let (stream, continuation) = AsyncStream.makeStream(
            of: StateSnapshot.self, bufferingPolicy: bufferingPolicy)
        let id = nextSubscriberID
        nextSubscriberID += 1
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeSubscriber(id) }
        }
        return (snapshot, stream, continuation)
    }

    /// The number of live subscribers (for tests and diagnostics).
    var subscriberCount: Int { subscribers.count }

    private func removeSubscriber(_ id: Int) {
        subscribers[id] = nil
    }

    private func commit(_ next: JSONValue, changed: Set<JSONPointer>) {
        state = next
        version += 1
        lastChanged = changed
        let current = snapshot
        for continuation in subscribers.values {
            continuation.yield(current)
        }
    }
}
