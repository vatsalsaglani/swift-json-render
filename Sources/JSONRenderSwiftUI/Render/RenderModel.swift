// Owner: jr-3 (wave 2). The observable model behind one `JSONRenderView`.
internal import Foundation
public import JSONRenderCore
public import Observation
internal import SwiftUI

/// The state of one rendered spec: the spec and its plan, the latest state snapshot, the
/// action dispatcher and the form validator.
///
/// - `run()` follows the store: one `stateSnapshot` publish per store commit the
///   subscription delivers (a slow reader sees only the newest).
/// - `write(_:_:)` applies a bound write locally at once (so a text field never lags),
///   then commits it to the store through one ordered chain. Store snapshots that arrive
///   while writes are in flight are held back until the chain is idle.
/// - `emit(id:event:payload:scope:)` runs the element's `on[event]` bindings one after
///   another in one task and stops at a declined confirmation or a failure.
///
/// Warnings (ids, types and slot names only) are recorded without publishing, so views
/// may record them while they render.
@MainActor
@Observable
public final class RenderModel {
    public private(set) var spec: Spec
    public private(set) var plan: RenderPlan
    public private(set) var stateSnapshot: StateSnapshot
    /// The first `Button` with `variant: "primary"` in plan order. It gets the default
    /// keyboard action (one per view).
    public private(set) var defaultActionElementID: String?

    @ObservationIgnored public let catalog: Catalog
    @ObservationIgnored public let store: StateStore
    @ObservationIgnored public let host: any ActionHost
    @ObservationIgnored public let dispatcher: ActionDispatcher
    @ObservationIgnored public let formValidator: FormValidator
    @ObservationIgnored public let limits: SpecLimits
    /// Writes bound values through this model. Stable for the model's life.
    @ObservationIgnored public private(set) var bindingWriter: JRBindingWriter = .none
    /// Opens links through the host. Stable for the model's life.
    @ObservationIgnored public private(set) var urlOpener: JRURLOpener = .none

    /// Each render warning once, in first-seen order (at most `warningCapacity`).
    @ObservationIgnored public private(set) var warnings: [RenderWarning] = []
    public static let warningCapacity = 200
    @ObservationIgnored private var seenWarnings: Set<RenderWarning> = []
    @ObservationIgnored private var pendingWrites = 0
    @ObservationIgnored private var writeChain: Task<Void, Never>?
    @ObservationIgnored private var heldSnapshot: StateSnapshot?

    /// A model for a whole spec. Without `store`, a new store starts with `spec.state`.
    public init(
        spec: Spec, catalog: Catalog, store: StateStore? = nil,
        host: any ActionHost = NoopActionHost(), limits: SpecLimits = .default,
        observer: (any ActionObserver)? = nil
    ) {
        let store = store ?? StateStore(initial: spec.state)
        self.spec = spec
        self.plan = RenderPlan(spec: spec, limits: limits)
        self.limits = limits
        self.catalog = catalog
        self.store = store
        self.host = host
        let validator = FormValidator(custom: catalog.validationFunctions)
        self.formValidator = validator
        self.dispatcher = ActionDispatcher(
            catalog: catalog, store: store, host: host, validation: validator, observer: observer)
        self.stateSnapshot = StateSnapshot(
            version: 0, state: RenderModel.objectState(spec.state), changed: [])
        finishInit()
    }

    /// A model for a stream snapshot. It uses `snapshot.plan` and never rebuilds it.
    public init(
        snapshot: SpecSnapshot, catalog: Catalog, store: StateStore,
        host: any ActionHost = NoopActionHost(), limits: SpecLimits = .default,
        observer: (any ActionObserver)? = nil
    ) {
        self.spec = snapshot.spec
        self.plan = snapshot.plan
        self.limits = limits
        self.catalog = catalog
        self.store = store
        self.host = host
        let validator = FormValidator(custom: catalog.validationFunctions)
        self.formValidator = validator
        self.dispatcher = ActionDispatcher(
            catalog: catalog, store: store, host: host, validation: validator, observer: observer)
        self.stateSnapshot = StateSnapshot(
            version: 0, state: RenderModel.objectState(snapshot.spec.state), changed: [])
        finishInit()
    }

    private func finishInit() {
        defaultActionElementID = RenderModel.firstPrimaryButton(spec: spec, plan: plan)
        bindingWriter = JRBindingWriter { [weak self] pointer, value in
            self?.write(pointer, value)
        }
        urlOpener = JRURLOpener { [host] url in
            Task { _ = await host.openURL(url) }
        }
    }

    // MARK: - Spec

    /// Replaces the spec. Rebuilds the plan only when the spec changed.
    public func update(spec newSpec: Spec) {
        guard newSpec != spec else { return }
        spec = newSpec
        plan = RenderPlan(spec: newSpec, limits: limits)
        defaultActionElementID = RenderModel.firstPrimaryButton(spec: spec, plan: plan)
    }

    /// Takes a stream snapshot's spec and plan (never recomputed).
    public func update(snapshot: SpecSnapshot) {
        guard snapshot.spec != spec || snapshot.plan != plan else { return }
        spec = snapshot.spec
        plan = snapshot.plan
        defaultActionElementID = RenderModel.firstPrimaryButton(spec: spec, plan: plan)
    }

    // MARK: - State

    /// Follows the store until cancelled. `JSONRenderView` runs it in a `.task`.
    public func run() async {
        let snapshots = await store.snapshots()
        for await snapshot in snapshots {
            if Task.isCancelled { return }
            receive(snapshot)
        }
    }

    private func receive(_ snapshot: StateSnapshot) {
        guard pendingWrites == 0 else {
            heldSnapshot = snapshot
            return
        }
        heldSnapshot = nil
        stateSnapshot = snapshot
    }

    /// Writes a bound value (`$bindState` / `$bindItem`). The model shows it at once; the
    /// store commits it in order. An equal value is a no-op.
    public func write(_ pointer: JSONPointer, _ value: JSONValue) {
        var state = stateSnapshot.state
        guard state.value(at: pointer) != value else { return }
        if state.set(value, at: pointer) {
            stateSnapshot = StateSnapshot(
                version: stateSnapshot.version, state: state, changed: [pointer])
        }
        pendingWrites += 1
        let previous = writeChain
        let store = self.store
        writeChain = Task { [weak self] in
            await previous?.value
            await store.set(pointer, value)
            let latest = await store.snapshot
            self?.finishWrite(latest)
        }
    }

    private func finishWrite(_ latest: StateSnapshot) {
        pendingWrites -= 1
        guard pendingWrites == 0 else { return }
        let snapshot = [heldSnapshot, latest].compactMap { $0 }.max { $0.version < $1.version }
        heldSnapshot = nil
        if let snapshot, snapshot.version >= stateSnapshot.version { stateSnapshot = snapshot }
    }

    /// Waits until every write so far has reached the store.
    public func flushWrites() async {
        await writeChain?.value
    }

    // MARK: - Actions

    /// Runs the element's `on[event]` bindings in order, each resolved against the live
    /// state in `scope`. Earlier bound writes land first. `payload` is not used by the
    /// standard actions (upstream `emit` has none); it is accepted for host components.
    @discardableResult
    public func emit(
        id: String, event: String, payload: [String: JSONValue] = [:], scope: RepeatScope? = nil
    ) -> Task<Void, Never> {
        let bindings = spec.elements[id]?.on?[event] ?? []
        guard !bindings.isEmpty else { return Task {} }
        let previous = writeChain
        let store = self.store
        let dispatcher = self.dispatcher
        let functions = catalog.functions
        let directives = catalog.directives
        return Task { [weak self] in
            await previous?.value
            for binding in bindings {
                let live = await store.snapshot
                let context = PropResolutionContext(
                    state: live.state, scope: scope, functions: functions, directives: directives)
                do {
                    let outcome = try await dispatcher.dispatch(
                        binding, elementID: id, context: context)
                    if outcome == .cancelled { return }
                } catch {
                    self?.record(.actionFailed(id: id, event: event))
                    return
                }
            }
        }
    }

    /// Runs the `watch` bindings of every element the walk draws until cancelled. Views run
    /// watchers through `WatchHost`; this is for headless hosts and tests. Each watcher's
    /// baseline is the state when this call subscribes (before it returns the task).
    public func startWatchers() async -> Task<Void, Never> {
        let walk = self.walk()
        let runner = WatchRunner(store: store, dispatcher: dispatcher)
        let functions = catalog.functions
        let directives = catalog.directives
        var jobs: [(String, [String: [ActionBinding]], RepeatScope?, StateSubscription)] = []
        for element in walk.elements where element.hasWatch {
            guard let watch = spec.elements[element.id]?.watch else { continue }
            jobs.append((element.id, watch, element.scope, await store.subscribe()))
        }
        return Task {
            await withTaskGroup(of: Void.self) { group in
                for (id, watch, scope, subscription) in jobs {
                    group.addTask {
                        await runner.run(
                            elementID: id, watch: watch, subscription: subscription
                        ) { snapshot in
                            PropResolutionContext(
                                state: snapshot.state, scope: scope, functions: functions,
                                directives: directives)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Warnings and walk

    /// Records a warning once. Does not publish (safe during a view update).
    public func record(_ warning: RenderWarning) {
        guard warnings.count < RenderModel.warningCapacity,
            seenWarnings.insert(warning).inserted
        else { return }
        warnings.append(warning)
    }

    /// The headless walk of the current spec and state.
    public func walk() -> RenderWalk {
        RenderWalk(
            spec: spec, plan: plan, state: stateSnapshot.state, catalog: catalog, limits: limits)
    }

    // MARK: - Helpers

    private static func objectState(_ state: JSONValue?) -> JSONValue {
        if case .object? = state, let state { return state }
        return .object([:])
    }

    private static func firstPrimaryButton(spec: Spec, plan: RenderPlan) -> String? {
        plan.order.first { id in
            guard let element = spec.elements[id], element.type == "Button" else { return false }
            return element.props["variant"] == .string("primary")
        }
    }
}
