// Owner: jr-2 (wave 2).
public import JSONRenderCore
public import Observation

/// Publish and drop counts of a stream's frame coalescer.
public struct StreamFrameStats: Sendable, Hashable {
    public var published: Int
    public var dropped: Int

    public init(published: Int = 0, dropped: Int = 0) {
        self.published = published
        self.dropped = dropped
    }
}

/// The observable side of one streamed spec: decoder, `SpecStore`, frame coalescer and the
/// live `StateStore`, run as one task tree by `run(_:mode:onFinish:)`.
///
/// - Phases: `idle` → `streaming` → `final` (normal end) or `stopped` (cancel, task
///   cancellation, or a stream that throws).
/// - `snapshot` changes at most once per display frame.
/// - State: while the stream runs, the stream's `/state` wins: after each commit whose
///   `spec.state` changed, `store.replaceAll` copies it in (a user write in that window is
///   overwritten). After the stream ends, the store belongs to the user; nothing is copied.
/// - A stream that throws journals `.unrecoverable(<error type name>)`, never the message.
/// - Decoding and patch application run off the main actor.
@MainActor @Observable public final class StreamModel {
    public private(set) var snapshot: SpecSnapshot
    public private(set) var phase: JRStreamPhase = .idle
    /// The same list as `snapshot.journal`.
    public private(set) var journal: [StreamError] = []
    /// The validation report of the final snapshot; `nil` until the stream finishes.
    public private(set) var report: ValidationReport?
    /// Coalescer counts, updated at each publish.
    public private(set) var frameStats = StreamFrameStats()
    /// The state the rendered spec reads and writes.
    public let store: StateStore

    @ObservationIgnored private let initial: Spec?
    @ObservationIgnored private let specStore: SpecStore
    @ObservationIgnored private let clock: any FrameClock
    @ObservationIgnored private var cancelSignal: AsyncStream<Void>.Continuation?

    public init(
        catalog: Catalog, initial: Spec? = nil, limits: SpecLimits = .default,
        clock: any FrameClock = DisplayLinkFrameClock(), store: StateStore? = nil
    ) {
        self.initial = initial
        self.clock = clock
        let specStore = SpecStore(catalog: catalog, initial: initial, limits: limits)
        self.specStore = specStore
        self.store = store ?? StateStore(initial: initial?.state)
        let spec = initial ?? Spec(root: "", elements: [:])
        snapshot = SpecSnapshot(version: 0, spec: spec, limits: limits)
    }

    /// Consumes `text` until it ends, throws, or the task is cancelled. Returns after the
    /// last publish. A second call while a stream runs returns at once; a call after a
    /// stream ended starts again from the initial spec.
    public func run(
        _ text: AsyncThrowingStream<String, any Error>, mode: SpecStreamDecoder.Mode,
        onFinish: ((ValidationReport) -> Void)? = nil
    ) async {
        guard phase != .streaming else { return }
        let specStore = specStore
        let store = store
        let needsReset = phase != .idle
        phase = .streaming  // before any suspension, so a second call returns at once
        report = nil
        if needsReset {
            await specStore.reset(initial)
        }
        let snapshots = await specStore.snapshots()
        let coalescer = FrameCoalescer<SpecSnapshot>(clock: clock)
        let (signal, cancelContinuation) = AsyncStream.makeStream(of: Void.self)
        cancelSignal = cancelContinuation
        defer {
            cancelContinuation.finish()
            cancelSignal = nil
        }

        let outcome: PumpOutcome = await withTaskGroup(of: PumpOutcome?.self) { group in
            group.addTask {
                await self.drive(coalescer, from: snapshots)
                return nil
            }
            group.addTask {
                await StreamModel.pump(text, mode: mode, into: specStore, mirror: store)
            }
            group.addTask {
                for await _ in signal { return .cancelled }
                return nil
            }
            var outcome = PumpOutcome.cancelled
            while let next = await group.next() {
                if let next {
                    outcome = next
                    break
                }
            }
            cancelContinuation.finish()
            switch outcome {
            case .completed:
                // Ends the snapshot stream; the coalescer publishes the final snapshot.
                let (report, final) = await specStore.finish()
                self.report = report
                await group.waitForAll()
                self.receive(final, stats: coalescer)
            case .cancelled, .failed:
                group.cancelAll()
                if case .failed(let typeName) = outcome {
                    await specStore.note(.unrecoverable(typeName))
                }
                let last = await specStore.cancel()
                await group.waitForAll()
                self.receive(last, stats: coalescer)
            }
            return outcome
        }

        switch outcome {
        case .completed:
            phase = .final
            if let report { onFinish?(report) }
        case .cancelled, .failed:
            phase = .stopped
        }
    }

    /// Stops the running stream. The last snapshot stays; `phase` becomes `.stopped`.
    public func cancel() {
        cancelSignal?.yield()
    }

    // MARK: - Implementation

    enum PumpOutcome: Sendable, Equatable {
        case completed, cancelled
        case failed(String)
    }

    private func drive(
        _ coalescer: FrameCoalescer<SpecSnapshot>, from snapshots: AsyncStream<SpecSnapshot>
    ) async {
        await coalescer.run(snapshots) { [weak self] snapshot in
            self?.receive(snapshot, stats: coalescer)
        }
    }

    private func receive(_ snapshot: SpecSnapshot, stats coalescer: FrameCoalescer<SpecSnapshot>) {
        if snapshot != self.snapshot { self.snapshot = snapshot }
        if journal != snapshot.journal { journal = snapshot.journal }
        let stats = StreamFrameStats(published: coalescer.published, dropped: coalescer.dropped)
        if stats != frameStats { frameStats = stats }
    }

    /// Reads `text`, decodes it, and applies each chunk's events as one commit. Runs off the
    /// main actor.
    nonisolated static func pump(
        _ text: AsyncThrowingStream<String, any Error>, mode: SpecStreamDecoder.Mode,
        into specStore: SpecStore, mirror store: StateStore
    ) async -> PumpOutcome {
        var decoder = SpecStreamDecoder(mode: mode)
        var mirrored = await specStore.current.spec.state
        if let mirrored { await store.replaceAll(mirrored) }

        func commit(_ events: [SpecStreamEvent]) async {
            guard !events.isEmpty else { return }
            await specStore.apply(events)
            let state = await specStore.current.spec.state
            if state != mirrored {
                mirrored = state
                await store.replaceAll(state ?? .object([:]))
            }
        }

        do {
            for try await chunk in text {
                if Task.isCancelled { return .cancelled }
                await commit(decoder.push(chunk))
            }
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(String(describing: type(of: error)))
        }
        if Task.isCancelled { return .cancelled }
        await commit(decoder.flush())
        return .completed
    }
}
