// Owner: jr-2 (wave 2).

/// The live document of a streaming (or patched) spec. Each commit gives one immutable
/// `SpecSnapshot` with its `RenderPlan`, built here and never in a view.
///
/// - The document is a `JSONValue`, not a `Spec`: patches may target any path (for example
///   `/elements/c1/props/data/-`). Each snapshot projects it with `Spec.lenient`.
/// - A patch never throws: a failure goes into the journal, and later patches still apply.
/// - Budgets: `SpecLimits.maxElements` (the `elements` member count) and `maxBytes` (a
///   running over-estimate from the patch values, never a re-encode of the document). The
///   first breach journals `.budget(kind)` once, refuses that patch and every later one, and
///   keeps the last good snapshot.
/// - Out-of-order patches need no special case: a child that arrives before its parent is
///   an element with no path from the root, and the plan lists it when the parent arrives.
/// - `finish` and `cancel` close the store: later patches are refused and every snapshot
///   stream ends. `reset` opens it again.
/// - The store logs nothing.
public actor SpecStore {
    private let catalog: Catalog
    private let limits: SpecLimits
    private var document: JSONValue
    private var estimatedBytes: Int
    private var version: UInt64
    private var journal: [StreamError] = []
    private var patchCount = 0
    private var breached: SpecLimitKind?
    private var closed = false
    private var finalReport: ValidationReport?
    private var latest: SpecSnapshot
    private var subscribers: [Int: AsyncStream<SpecSnapshot>.Continuation] = [:]
    private var nextSubscriberID = 0

    public init(catalog: Catalog, initial: Spec? = nil, limits: SpecLimits = .default) {
        self.catalog = catalog
        self.limits = limits
        let document = initial?.jsonValue ?? .object([:])
        self.document = document
        estimatedBytes = document.estimatedByteCount
        version = 0
        latest = SpecStore.snapshot(of: document, version: 0, journal: [], limits: limits)
    }

    deinit {
        for continuation in subscribers.values {
            continuation.finish()
        }
    }

    /// The latest snapshot.
    public var current: SpecSnapshot { latest }

    /// `true` after `finish` or `cancel`, until `reset`.
    public var isClosed: Bool { closed }

    /// Applies one patch as one commit with one snapshot. Returns the error, if any.
    @discardableResult
    public func apply(_ patch: SpecPatch) -> StreamError? {
        apply([SpecStreamEvent.patch(patch)]).first
    }

    /// Applies the patches in order as one commit with one snapshot.
    @discardableResult
    public func apply(_ patches: [SpecPatch]) -> [StreamError] {
        apply(patches.map(SpecStreamEvent.patch))
    }

    /// Applies a decoder's events in order as one commit with one snapshot: patches are
    /// applied, errors are journaled, text is ignored. Returns this batch's errors.
    @discardableResult
    public func apply(_ events: [SpecStreamEvent]) -> [StreamError] {
        guard !events.isEmpty else { return [] }
        guard !closed else { return [.unrecoverable("store closed")] }
        var errors: [StreamError] = []
        var journaled = 0
        var changed = false
        for event in events {
            switch event {
            case .text:
                continue
            case .error(let error):
                errors.append(error)
                journal.append(error)
                journaled += 1
            case .patch(let patch):
                if let breached {
                    errors.append(.budget(breached))
                    continue
                }
                let index = patchCount
                patchCount += 1
                var next = document
                do {
                    try next.apply(patch, index: index)
                } catch {
                    errors.append(error)
                    journal.append(error)
                    journaled += 1
                    continue
                }
                let bytes = max(0, estimatedBytes + byteDelta(patch, before: document))
                let kind: SpecLimitKind? =
                    if bytes > limits.maxBytes {
                        .bytes
                    } else if (next["elements"]?.objectValue?.count ?? 0) > limits.maxElements {
                        .elements
                    } else {
                        nil
                    }
                if let kind {
                    breached = kind
                    errors.append(.budget(kind))
                    journal.append(.budget(kind))
                    journaled += 1
                    continue
                }
                document = next
                estimatedBytes = bytes
                changed = true
            }
        }
        if changed {
            commit(rebuild: true)
        } else if journaled > 0 {
            commit(rebuild: false)
        }
        return errors
    }

    /// Records a decoder or transport error in the journal (one commit).
    public func note(_ error: StreamError) {
        guard !closed else { return }
        journal.append(error)
        commit(rebuild: false)
    }

    /// Ends the stream: validates, prunes dangling ids, and commits the final snapshot
    /// (`isFinal == true`, `dangling == []`). Ends every snapshot stream. Calling it again
    /// returns the same result.
    ///
    /// The prune removes every `children` and `slots` id that has no element. It is done
    /// here, not with `Catalog.autoFix(_:lossy:)`, because `autoFix` also moves fields out
    /// of `props` and keeps the ids of a repeat container whose children are all missing.
    /// Validation runs after the prune, without the orphan check.
    public func finish(validate: Bool = true, prune: Bool = true) -> (
        ValidationReport, SpecSnapshot
    ) {
        if closed, latest.isFinal, let finalReport { return (finalReport, latest) }
        var spec = Spec.lenient(document).spec
        if prune { spec = SpecStore.pruned(spec) }
        let report =
            validate
            ? catalog.validate(
                spec, options: ValidateSpecOptions(checkOrphans: false), limits: limits)
            : ValidationReport(issues: [])
        version += 1
        latest = SpecSnapshot(
            version: version, spec: spec, plan: RenderPlan(spec: spec, limits: limits),
            dangling: [], isFinal: true, journal: journal)
        finalReport = report
        closed = true
        broadcast(latest)
        endSubscribers()
        return (report, latest)
    }

    /// Stops the stream: keeps the last snapshot (`isFinal == false`), runs no validation,
    /// and ends every snapshot stream.
    @discardableResult
    public func cancel() -> SpecSnapshot {
        closed = true
        endSubscribers()
        return latest
    }

    /// Upstream `compiler.reset`: a new document, an empty journal, an open store. The
    /// version keeps counting up.
    public func reset(_ initial: Spec? = nil) {
        document = initial?.jsonValue ?? .object([:])
        estimatedBytes = document.estimatedByteCount
        journal = []
        patchCount = 0
        breached = nil
        closed = false
        finalReport = nil
        commit(rebuild: true)
    }

    /// A new stream of snapshots: the current one first, then one per commit. Each call
    /// gives its own stream. A stream ends when the store finishes, is cancelled or is
    /// released. The default policy keeps only the newest snapshot for a slow reader, so it
    /// never blocks the decoder.
    public func snapshots(
        bufferingPolicy: AsyncStream<SpecSnapshot>.Continuation.BufferingPolicy =
            .bufferingNewest(1)
    ) -> AsyncStream<SpecSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(
            of: SpecSnapshot.self, bufferingPolicy: bufferingPolicy)
        continuation.yield(latest)
        if closed {
            continuation.finish()
            return stream
        }
        let id = nextSubscriberID
        nextSubscriberID += 1
        subscribers[id] = continuation
        continuation.onTermination = { [weak self] _ in
            guard let self else { return }
            Task { await self.removeSubscriber(id) }
        }
        return stream
    }

    /// Patch mode (upstream "edit" with patches; `view_update`): applies `patches` to `spec`
    /// as one commit and validates the result. Nothing is pruned.
    public static func applying(
        _ patches: [SpecPatch], to spec: Spec, catalog: Catalog, limits: SpecLimits = .default
    ) async -> (Spec, [StreamError], ValidationReport) {
        let store = SpecStore(catalog: catalog, initial: spec, limits: limits)
        let errors = await store.apply(patches)
        let (report, snapshot) = await store.finish(validate: true, prune: false)
        return (snapshot.spec, errors, report)
    }

    /// The number of live subscribers (for tests and diagnostics).
    var subscriberCount: Int { subscribers.count }

    // MARK: - Implementation

    private func removeSubscriber(_ id: Int) {
        subscribers[id] = nil
    }

    private func commit(rebuild: Bool) {
        version += 1
        if rebuild {
            latest = SpecStore.snapshot(
                of: document, version: version, journal: journal, limits: limits)
        } else {
            latest = SpecSnapshot(
                version: version, spec: latest.spec, plan: latest.plan, dangling: latest.dangling,
                isFinal: false, journal: journal)
        }
        broadcast(latest)
    }

    private func broadcast(_ snapshot: SpecSnapshot) {
        for continuation in subscribers.values {
            continuation.yield(snapshot)
        }
    }

    private func endSubscribers() {
        let continuations = subscribers.values
        subscribers = [:]
        for continuation in continuations {
            continuation.finish()
        }
    }

    private static func snapshot(
        of document: JSONValue, version: UInt64, journal: [StreamError], limits: SpecLimits
    ) -> SpecSnapshot {
        let spec = Spec.lenient(document).spec
        return SpecSnapshot(
            version: version, spec: spec, plan: RenderPlan(spec: spec, limits: limits),
            journal: journal)
    }

    /// Removes `children` and `slots` ids that have no element.
    static func pruned(_ spec: Spec) -> Spec {
        var elements = spec.elements
        for id in spec.elements.keys.sorted() {
            guard var element = elements[id] else { continue }
            var changed = false
            if let children = element.children {
                let present = children.filter { spec.elements[$0] != nil }
                if present.count != children.count {
                    element.children = present
                    changed = true
                }
            }
            if let slots = element.slots {
                var kept: [String: [String]] = [:]
                for (name, ids) in slots {
                    let present = ids.filter { spec.elements[$0] != nil }
                    if present.count != ids.count { changed = true }
                    kept[name] = present
                }
                element.slots = kept
            }
            if changed { elements[id] = element }
        }
        return Spec(root: spec.root, elements: elements, state: spec.state)
    }

    /// The change in the estimated document size. Over-estimates are fine; `move` counts as
    /// no change.
    private func byteDelta(_ patch: SpecPatch, before: JSONValue) -> Int {
        guard let path = try? JSONPointer(patch.path) else { return 0 }
        let key = (path.tokens.last?.utf8.count ?? 0) * 2 + 4
        let old = before.value(at: path)?.estimatedByteCount
        let parentIsArray: Bool =
            if let parent = path.parent, case .array? = before.value(at: parent) { true } else {
                false
            }
        let written: Int =
            switch patch.op {
            case .copy:
                patch.from.flatMap { try? JSONPointer($0) }.flatMap { before.value(at: $0) }?
                    .estimatedByteCount ?? 0
            default:
                patch.value?.estimatedByteCount ?? 0
            }
        switch patch.op {
        case .add, .copy:
            if parentIsArray { return written + 1 }
            return written - (old ?? -key)
        case .replace:
            return written - (old ?? -key)
        case .remove:
            return -(old ?? 0)
        case .move, .test:
            return 0
        }
    }
}
