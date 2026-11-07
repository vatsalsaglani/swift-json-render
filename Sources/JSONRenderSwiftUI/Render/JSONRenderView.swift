// Owner: jr-3 (wave 2). The public entry point: a spec plus a state store to native views.
public import JSONRenderCore
public import SwiftUI

/// Renders a json-render spec with a catalog.
///
/// ```swift
/// JSONRenderView(spec: spec, catalog: try .standard)
///     .jsonRenderTheme(.native)
/// ```
///
/// One `RenderModel` per view: it owns the plan, follows the state store and dispatches
/// actions. The view sets `\.jrRenderChild` (children render through it) and
/// `\.jrWriteBinding` (bound controls write through it).
public struct JSONRenderView: View {
    private enum Source {
        case spec(Spec, StateStore?, SpecLimits)
        case snapshot(SpecSnapshot, StateStore)
        case model(RenderModel)
    }

    private let source: Source
    private let catalog: Catalog?
    private let host: any ActionHost
    private let observer: (any ActionObserver)?
    @State private var ownModel: RenderModel?

    /// Renders `spec`. Without `state`, a new store starts with `spec.state`; a changed
    /// spec keeps the store and rebuilds the plan.
    public init(
        spec: Spec, catalog: Catalog, state: StateStore? = nil,
        host: any ActionHost = NoopActionHost(), limits: SpecLimits = .default,
        observer: (any ActionObserver)? = nil
    ) {
        self.source = .spec(spec, state, limits)
        self.catalog = catalog
        self.host = host
        self.observer = observer
    }

    /// Renders a stream snapshot with the stream's store. The plan comes from the snapshot;
    /// `\.jrStreamPhase` decides skeleton or fallback for ids that do not exist yet.
    public init(
        snapshot: SpecSnapshot, catalog: Catalog, store: StateStore,
        host: any ActionHost = NoopActionHost(), observer: (any ActionObserver)? = nil
    ) {
        self.source = .snapshot(snapshot, store)
        self.catalog = catalog
        self.host = host
        self.observer = observer
    }

    /// Renders a model the host owns (to read its warnings, emit, or share it).
    public init(model: RenderModel) {
        self.source = .model(model)
        self.catalog = nil
        self.host = NoopActionHost()
        self.observer = nil
    }

    public var body: some View {
        Group {
            if let model = activeModel {
                JSONRenderRoot(model: model)
            } else {
                Color.clear.frame(width: 0, height: 0)
            }
        }
        .onAppear(perform: makeModelIfNeeded)
        .onChange(of: specInput) { _, newSpec in
            if let newSpec { ownModel?.update(spec: newSpec) }
        }
        .onChange(of: snapshotInput) { _, newSnapshot in
            if let newSnapshot { ownModel?.update(snapshot: newSnapshot) }
        }
    }

    private var activeModel: RenderModel? {
        if case .model(let model) = source { return model }
        return ownModel
    }

    private var specInput: Spec? {
        if case .spec(let spec, _, _) = source { return spec }
        return nil
    }

    private var snapshotInput: SpecSnapshot? {
        if case .snapshot(let snapshot, _) = source { return snapshot }
        return nil
    }

    private func makeModelIfNeeded() {
        guard ownModel == nil, let catalog else { return }
        switch source {
        case .spec(let spec, let store, let limits):
            ownModel = RenderModel(
                spec: spec, catalog: catalog, store: store, host: host, limits: limits,
                observer: observer)
        case .snapshot(let snapshot, let store):
            ownModel = RenderModel(
                snapshot: snapshot, catalog: catalog, store: store, host: host,
                observer: observer)
        case .model:
            break
        }
    }
}

/// The root of one render: sets the renderer environment and follows the store.
private struct JSONRenderRoot: View {
    let model: RenderModel
    @Environment(\.jrStreamPhase) private var phase
    @Environment(\.jsonRenderTheme) private var theme

    /// One renderer for every view: it closes over nothing, so its id never changes.
    private static let renderChild = JRRenderChild(
        id: UUID(uuidString: "6A7C1D52-3B0E-4F7A-9D5E-0C2B8E61A001") ?? UUID()
    ) { id in
        AnyView(ElementView(id: id))
    }

    var body: some View {
        Group {
            if let root = model.plan.rootID {
                ElementView(id: root)
            } else if phase == .streaming {
                JRSkeletonPlaceholder(shape: .card)
            }
        }
        .environment(\.jrRenderModel, model)
        .environment(\.jrRenderChild, JSONRenderRoot.renderChild)
        .environment(\.jrWriteBinding, model.bindingWriter)
        .environment(\.jrFormValidator, model.formValidator)
        .environment(\.jrDefaultActionElementID, model.defaultActionElementID)
        .environment(\.jrURLOpener, model.urlOpener)
        .onAppear { ThemeContrastAudit.check(theme) }
        .task { await model.run() }
    }
}
