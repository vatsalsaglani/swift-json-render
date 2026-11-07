// Owner: jr-2 (wave 2).
import Foundation
import os

#if canImport(AppKit)
    import AppKit
    import QuartzCore
#elseif canImport(UIKit)
    import UIKit
    import QuartzCore
#endif

/// A source of display-frame ticks.
public protocol FrameClock: Sendable {
    /// One instant per display frame. The stream ends when the consumer stops iterating.
    func ticks() -> AsyncStream<ContinuousClock.Instant>
}

/// Ticks from the display link of the main screen (`NSScreen.displayLink(target:selector:)`
/// on macOS 14, `CADisplayLink` on iOS). Without a screen (headless runs, tests, a closed
/// lid) it falls back to a 16 ms `ContinuousClock` loop.
public struct DisplayLinkFrameClock: FrameClock {
    public init() {}

    public func ticks() -> AsyncStream<ContinuousClock.Instant> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: ContinuousClock.Instant.self, bufferingPolicy: .bufferingNewest(1))
        let driver = Task { @MainActor in
            if let target = DisplayLinkTarget.start(continuation) {
                continuation.onTermination = { _ in Task { @MainActor in target.stop() } }
                return
            }
            let clock = ContinuousClock()
            while !Task.isCancelled {
                do {
                    try await clock.sleep(for: .milliseconds(16))
                } catch {
                    return
                }
                continuation.yield(clock.now)
            }
        }
        continuation.onTermination = { _ in driver.cancel() }
        return stream
    }
}

/// The `@objc` target a display link calls. It lives on the main actor.
@MainActor
private final class DisplayLinkTarget: NSObject {
    private let continuation: AsyncStream<ContinuousClock.Instant>.Continuation
    private var link: CADisplayLink?

    private init(continuation: AsyncStream<ContinuousClock.Instant>.Continuation) {
        self.continuation = continuation
    }

    /// A running link, or `nil` when there is no screen.
    static func start(_ continuation: AsyncStream<ContinuousClock.Instant>.Continuation)
        -> DisplayLinkTarget?
    {
        let target = DisplayLinkTarget(continuation: continuation)
        #if canImport(AppKit)
            guard let screen = NSScreen.main else { return nil }
            let link = screen.displayLink(target: target, selector: #selector(step(_:)))
        #elseif canImport(UIKit)
            let link = CADisplayLink(target: target, selector: #selector(step(_:)))
        #else
            return nil
        #endif
        link.add(to: .main, forMode: .common)
        target.link = link
        return target
    }

    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        // A consumer that went away before `onTermination` was set still stops the link.
        if case .terminated = continuation.yield(ContinuousClock.now) { stop() }
    }
}

/// A clock that ticks only when a test calls `tick()`.
public struct ManualFrameClock: FrameClock {
    private let state = ManualFrameClockState()

    public init() {}

    public func ticks() -> AsyncStream<ContinuousClock.Instant> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: ContinuousClock.Instant.self, bufferingPolicy: .unbounded)
        state.add(continuation)
        return stream
    }

    /// Sends one tick to every current consumer.
    public func tick() {
        state.tick()
    }

    /// The ticks sent so far.
    public var tickCount: Int { state.count }
}

/// Shared mutable state of a `ManualFrameClock`, behind a lock.
private final class ManualFrameClockState: Sendable {
    private struct Contents {
        var continuations: [AsyncStream<ContinuousClock.Instant>.Continuation] = []
        var count = 0
    }

    private let contents = OSAllocatedUnfairLock(initialState: Contents())

    func add(_ continuation: AsyncStream<ContinuousClock.Instant>.Continuation) {
        contents.withLock { $0.continuations.append(continuation) }
    }

    func tick() {
        let continuations = contents.withLock { contents in
            contents.count += 1
            return contents.continuations
        }
        let now = ContinuousClock.now
        for continuation in continuations {
            continuation.yield(now)
        }
    }

    var count: Int { contents.withLock { $0.count } }
}
