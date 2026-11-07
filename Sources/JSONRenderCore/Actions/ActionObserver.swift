public import Foundation

/// Sent when an action starts (upstream `ActionDispatchInfo`, without params: observers
/// see ids, names and the element id only, never values).
public struct ActionDispatchInfo: Sendable, Hashable {
    /// Pairs this event with its `ActionSettleInfo`.
    public let id: String
    public let name: String
    public let elementID: String?
    public let at: Date

    public init(id: String, name: String, elementID: String?, at: Date) {
        self.id = id
        self.name = name
        self.elementID = elementID
        self.at = at
    }
}

/// Sent when an action ends (upstream `ActionSettleInfo`, without the result or error
/// value).
public struct ActionSettleInfo: Sendable, Hashable {
    /// How the dispatch ended.
    public enum Outcome: String, Sendable, Hashable {
        /// A built-in or a handler ran (an error handled by `onError` also counts).
        case completed
        /// The user declined the confirmation.
        case cancelled
        /// No built-in and no catalog handler has this name. Nothing ran.
        case noHandler
        /// A required provider is missing (`validateForm` without a validation provider).
        case unavailable
        /// The error was rethrown to the caller.
        case failed
    }

    public let id: String
    public let name: String
    public let elementID: String?
    /// `true` only for `.completed`. Cancelled and failed dispatches reject upstream;
    /// `.noHandler` and `.unavailable` make upstream warn.
    public let ok: Bool
    public let outcome: Outcome
    public let at: Date
    public let duration: Duration

    public init(
        id: String, name: String, elementID: String?, ok: Bool, outcome: Outcome, at: Date,
        duration: Duration
    ) {
        self.id = id
        self.name = name
        self.elementID = elementID
        self.ok = ok
        self.outcome = outcome
        self.at = at
        self.duration = duration
    }
}

/// Observes action lifecycles (upstream `action-observer.ts`). There is no global
/// registry: pass an observer to the `ActionDispatcher`. Calls are synchronous; keep them
/// cheap.
public protocol ActionObserver: Sendable {
    func dispatched(_ info: ActionDispatchInfo)
    func settled(_ info: ActionSettleInfo)
}
