// Owner: jr-3 (wave 2). The headless render walk: no SwiftUI.
public import JSONRenderCore

/// Walks a spec the way `JSONRenderView` draws it, without views: from the root over
/// visible elements, children (once per row for a `repeat`), then named slots in name
/// order. It records what each element would receive and every render warning.
///
/// Uses: the fallback check over the fixture specs, the semantics-invariance suite, the
/// accessibility audit, headless watchers. Recursion follows element depth, which the
/// render plan caps at `SpecLimits.maxDepth`.
public struct RenderWalk: Sendable {
    /// One drawn element: the data its render context carries.
    public struct Element: Sendable, Hashable {
        public let id: String
        public let type: String
        public let scope: RepeatScope?
        public let props: [String: JSONValue?]
        public let bindings: [String: JSONPointer]
        /// Event names of the element `on` field, sorted.
        public let events: [String]
        /// `true` when the element has a `watch` field.
        public let hasWatch: Bool
    }

    /// An element whose `watch` bindings run: drawn, hidden or of an unknown type (upstream
    /// runs `watch` regardless of visibility). Children of a hidden element are not visited.
    public struct WatchSite: Sendable, Hashable {
        public let id: String
        public let scope: RepeatScope?
    }

    /// The drawn elements in draw order.
    public private(set) var elements: [Element] = []
    /// The elements with a non-empty `watch` field, in visit order, including hidden and
    /// unknown-type elements (which `elements` leaves out).
    public private(set) var watchSites: [WatchSite] = []
    /// Each warning once, in first-seen order.
    public private(set) var warnings: [RenderWarning] = []
    private var seen: Set<RenderWarning> = []

    public init(
        spec: Spec, plan: RenderPlan, state: JSONValue, catalog: Catalog,
        limits: SpecLimits = .default
    ) {
        guard let root = plan.rootID else {
            if !spec.root.isEmpty { record(.missingElement(id: spec.root)) }
            return
        }
        var walker = Walker(spec: spec, plan: plan, state: state, catalog: catalog, limits: limits)
        walker.visit(root, scope: nil, ancestors: [])
        elements = walker.elements
        watchSites = walker.watchSites
        for warning in walker.warnings { record(warning) }
    }

    /// The warnings that draw a fallback block.
    public var fallbacks: [RenderWarning] { warnings.filter(\.isFallback) }

    private mutating func record(_ warning: RenderWarning) {
        if seen.insert(warning).inserted { warnings.append(warning) }
    }

    private struct Walker {
        let spec: Spec
        let plan: RenderPlan
        let state: JSONValue
        let catalog: Catalog
        let limits: SpecLimits
        var elements: [Element] = []
        var watchSites: [WatchSite] = []
        var warnings: [RenderWarning] = []

        init(spec: Spec, plan: RenderPlan, state: JSONValue, catalog: Catalog, limits: SpecLimits) {
            self.spec = spec
            self.plan = plan
            self.state = state
            self.catalog = catalog
            self.limits = limits
        }

        mutating func visit(_ id: String, scope: RepeatScope?, ancestors: Set<String>) {
            guard !ancestors.contains(id) else {
                warnings.append(.cycle(id: id))
                return
            }
            guard let node = plan.nodes[id], let element = spec.elements[id] else {
                warnings.append(.missingElement(id: id))
                return
            }
            guard !plan.truncatedAtDepth.contains(id) else {
                warnings.append(.tooDeep(id: id))
                return
            }
            let resolved = ElementResolution.resolve(
                element: element, scope: scope, state: state, catalog: catalog)
            warnings += resolved.warnings.map { .resolution(id: id, $0) }
            if !(element.watch ?? [:]).isEmpty {
                watchSites.append(WatchSite(id: id, scope: scope))
            }
            guard resolved.isVisible else { return }
            guard catalog.renderers[node.type] != nil else {
                warnings.append(.unknownType(id: id, type: node.type))
                return
            }
            warnings += ElementResolution.slotWarnings(
                id: id, type: node.type, slots: node.slotIDs,
                declared: catalog.component(named: node.type)?.slots ?? [])
            elements.append(
                Element(
                    id: id, type: node.type, scope: scope, props: resolved.props,
                    bindings: resolved.bindings, events: (element.on ?? [:]).keys.sorted(),
                    hasWatch: !(element.watch ?? [:]).isEmpty))
            let inner = ancestors.union([id])
            let children = ElementResolution.childIDs(of: node)
            if element.repeat != nil {
                let rows = ElementResolution.repeatRows(
                    element: element, id: id, scope: scope, state: state,
                    itemFilter: resolved.itemFilter, limits: limits)
                warnings += rows.warnings
                for row in rows.scopes {
                    for child in children { visit(child, scope: row, ancestors: inner) }
                }
            } else {
                for child in children { visit(child, scope: scope, ancestors: inner) }
            }
            let slots = ElementResolution.namedSlots(of: node)
            for name in slots.keys.sorted() {
                for child in slots[name] ?? [] { visit(child, scope: scope, ancestors: inner) }
            }
        }
    }
}
