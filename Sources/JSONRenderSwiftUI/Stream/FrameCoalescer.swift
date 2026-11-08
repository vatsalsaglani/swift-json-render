// Owner: jr-2 (wave 2).
import os

/// Publishes at most one value per display frame.
///
/// Between two ticks only the newest value is kept; each value it replaces counts as a
/// drop. On a tick the kept value is published once, and only when it differs from the
/// last published value. When no tick arrives within `fallbackDelay` of a new value (a
/// paused display link, a headless run), the value is published anyway, so nothing waits
/// for ever. When the source ends, the kept value is published at once.
///
/// Signposts (subsystem `com.vatsalsaglani.swift-json-render`, category `stream`): an
/// interval `jsonrender.stream.publish` around each publish, an event
/// `jsonrender.stream.drop` per drop.
@MainActor public final class FrameCoalescer<Value: Sendable & Equatable> {
    /// Values published.
    public private(set) var published = 0
    /// Values replaced before they were published.
    public private(set) var dropped = 0
    /// Of `published`, the values the fallback published without a tick.
    public private(set) var fallbackPublished = 0

    private let clock: any FrameClock
    private let fallbackDelay: Duration?
    private let signposter = OSSignposter(
        subsystem: "com.vatsalsaglani.swift-json-render", category: "stream")
    private var pending: Value?
    private var last: Value?
    private var generation = 0
    private var publisher: (@MainActor (Value) -> Void)?

    /// `fallbackDelay: nil` turns the headless fallback off.
    public init(
        clock: any FrameClock = DisplayLinkFrameClock(),
        fallbackDelay: Duration? = .milliseconds(50)
    ) {
        self.clock = clock
        self.fallbackDelay = fallbackDelay
    }

    /// Runs until `source` ends (then publishes the kept value) or the task is cancelled
    /// (then publishes nothing more).
    public func run(_ source: AsyncStream<Value>, publish: @MainActor @escaping (Value) -> Void)
        async
    {
        publisher = publish
        defer { publisher = nil }
        let (armed, arm) = AsyncStream.makeStream(
            of: Int.self, bufferingPolicy: .bufferingNewest(1))
        let ticks = clock.ticks()
        let fallbackDelay = fallbackDelay
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await value in source {
                    if let generation = await self.offerFromSource(value), fallbackDelay != nil {
                        arm.yield(generation)
                    }
                }
            }
            group.addTask {
                for await _ in ticks { await self.tick() }
            }
            if let fallbackDelay {
                group.addTask {
                    let clock = ContinuousClock()
                    for await generation in armed {
                        do {
                            try await clock.sleep(for: fallbackDelay)
                        } catch {
                            return
                        }
                        await self.fallback(generation)
                    }
                }
            }
            await group.next()  // the source ended or the task was cancelled
            group.cancelAll()
            arm.finish()
        }
        if !Task.isCancelled { flush() }
    }

    /// Keeps `value` for the next tick. Returns `true` when nothing was pending before (a
    /// new frame window starts). Internal: `run` drives it; tests use `@testable import`.
    @discardableResult
    func offer(_ value: Value) -> Bool {
        if pending != nil {
            dropped += 1
            signposter.emitEvent("jsonrender.stream.drop")
            pending = value
            return false
        }
        pending = value
        generation += 1
        return true
    }

    /// `offer`, returning the new frame window's generation when one starts.
    private func offerFromSource(_ value: Value) -> Int? {
        offer(value) ? generation : nil
    }

    /// One display frame: publishes the kept value if it changed. Internal, like `offer`.
    func tick() {
        flush()
    }

    private func fallback(_ generation: Int) {
        if generation == self.generation, flush() { fallbackPublished += 1 }
    }

    @discardableResult
    private func flush() -> Bool {
        guard let value = pending else { return false }
        pending = nil
        guard value != last else { return false }
        last = value
        published += 1
        let state = signposter.beginInterval("jsonrender.stream.publish")
        publisher?(value)
        signposter.endInterval("jsonrender.stream.publish", state)
        return true
    }
}
