/// One committed state value.
public struct StateSnapshot: Sendable, Hashable {
    /// Increases by one per commit. The initial state is version 0.
    public let version: UInt64
    /// The whole state object.
    public let state: JSONValue
    /// The pointers written in this commit (`[root]` for `replaceAll`; empty for version 0).
    public let changed: Set<JSONPointer>

    public init(version: UInt64, state: JSONValue, changed: Set<JSONPointer>) {
        self.version = version
        self.state = state
        self.changed = changed
    }
}

/// A snapshot and the commits after it (`StateStore.subscribe()`).
public struct StateSubscription: Sendable {
    /// The state when the subscription started.
    public let current: StateSnapshot
    /// One snapshot per later commit.
    public let updates: AsyncStream<StateSnapshot>

    public init(current: StateSnapshot, updates: AsyncStream<StateSnapshot>) {
        self.current = current
        self.updates = updates
    }
}
