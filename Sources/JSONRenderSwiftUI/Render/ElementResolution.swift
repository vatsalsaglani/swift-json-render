// Owner: jr-3 (wave 2). Pure element resolution: no SwiftUI, so it is unit-testable.
public import JSONRenderCore

/// A render problem. Carries ids, types, slot names and counts, never prop or state values.
public enum RenderWarning: Sendable, Hashable {
    /// The catalog has no renderer for `type`. A fallback block is drawn.
    case unknownType(id: String, type: String)
    /// A child or root id has no element (after the stream finished).
    case missingElement(id: String)
    /// The element is its own ancestor. A fallback block is drawn.
    case cycle(id: String)
    /// The element is deeper than `SpecLimits.maxDepth`. A fallback block is drawn.
    case tooDeep(id: String)
    /// `repeat.statePath` does not resolve (for example `$item` outside a repeat).
    case repeatPathInvalid(id: String)
    /// `repeat.statePath` does not point at an array. Nothing is repeated.
    case repeatNotArray(id: String)
    /// The repeated array has more rows than `SpecLimits.maxRepeatRows`; the rest are cut.
    case tooManyRows(id: String, count: Int)
    /// The spec uses `slots.default`; use `children` (upstream warns the same).
    case defaultSlot(id: String, type: String)
    /// The spec uses a slot the component does not declare.
    case unknownSlot(id: String, type: String, slot: String)
    /// A prop expression problem.
    case resolution(id: String, ResolutionWarning)
    /// An action of an event failed and had no `onError`.
    case actionFailed(id: String, event: String)

    /// `true` for the warnings that draw a fallback block in place of a component.
    public var isFallback: Bool {
        switch self {
        case .unknownType, .missingElement, .cycle, .tooDeep: true
        default: false
        }
    }

    /// The element id the warning is about.
    public var elementID: String {
        switch self {
        case .unknownType(let id, _), .missingElement(let id), .cycle(let id), .tooDeep(let id),
            .repeatPathInvalid(let id), .repeatNotArray(let id), .tooManyRows(let id, _),
            .defaultSlot(let id, _), .unknownSlot(let id, _, _), .resolution(let id, _),
            .actionFailed(let id, _):
            id
        }
    }
}

/// One element's resolved props, bindings and visibility for one render.
public struct ResolvedElement: Sendable, Hashable {
    /// The resolved props; `nil` is upstream undefined. Empty when not visible.
    public let props: [String: JSONValue?]
    /// Prop name to absolute state path (`$bindState`, `$bindItem`).
    public let bindings: [String: JSONPointer]
    /// The container part of `visible` (the whole condition when there is no `repeat`).
    public let isVisible: Bool
    /// The per-row part of `visible` for a `repeat` element.
    public let itemFilter: VisibilityCondition?
    public let warnings: [ResolutionWarning]
}

/// The rows of a `repeat` element.
public struct RepeatRows: Sendable, Hashable {
    /// One scope per kept row, in array order. A filtered row keeps its array index.
    public let scopes: [RepeatScope]
    public let warnings: [RenderWarning]
}

/// Element resolution shared by the views, the headless walk and the tests.
public enum ElementResolution {
    /// Resolves one element in `scope` against `state`, with the catalog's functions and
    /// directives. Props are resolved only when the element is visible.
    public static func resolve(
        element: UIElement, scope: RepeatScope?, state: JSONValue, catalog: Catalog
    ) -> ResolvedElement {
        let context = PropResolutionContext(
            state: state, scope: scope, functions: catalog.functions,
            directives: catalog.directives)
        let gate: VisibilityCondition?
        let itemFilter: VisibilityCondition?
        if element.repeat != nil {
            (gate, itemFilter) = VisibilityCondition.splitForRepeat(element.visible)
        } else {
            (gate, itemFilter) = (element.visible, nil)
        }
        guard VisibilityEvaluator.evaluate(gate, in: context.visibility) else {
            return ResolvedElement(
                props: [:], bindings: [:], isVisible: false, itemFilter: itemFilter, warnings: [])
        }
        var resolver = PropResolver(context: context)
        let props = resolver.resolveProps(element.props)
        let bindings = resolver.bindings(in: element.props)
        return ResolvedElement(
            props: props, bindings: bindings, isVisible: true, itemFilter: itemFilter,
            warnings: resolver.warnings)
    }

    /// The rows of `element.repeat` (empty when the element has none). The array is read
    /// at the resolved state path; rows past `limits.maxRepeatRows` are cut; `itemFilter`
    /// drops rows for which it is false.
    public static func repeatRows(
        element: UIElement, id: String, scope: RepeatScope?, state: JSONValue,
        itemFilter: VisibilityCondition?, limits: SpecLimits
    ) -> RepeatRows {
        guard let config = element.repeat else { return RepeatRows(scopes: [], warnings: []) }
        guard
            let path = RepeatScope.resolveStatePath(config.statePath, enclosing: scope?.basePath)
        else {
            return RepeatRows(scopes: [], warnings: [.repeatPathInvalid(id: id)])
        }
        guard case .array(let items)? = state.value(at: path) else {
            return RepeatRows(scopes: [], warnings: [.repeatNotArray(id: id)])
        }
        var warnings: [RenderWarning] = []
        let count = min(items.count, limits.maxRepeatRows)
        if items.count > limits.maxRepeatRows {
            warnings.append(.tooManyRows(id: id, count: items.count))
        }
        var scopes: [RepeatScope] = []
        scopes.reserveCapacity(count)
        for index in 0..<count {
            let item = items[index]
            if let itemFilter {
                let visibility = VisibilityContext(
                    state: state, repeatItem: item, repeatIndex: index)
                guard VisibilityEvaluator.evaluate(itemFilter, in: visibility) else { continue }
            }
            let key = config.key.flatMap { field -> String? in
                switch item[field] {
                case .string(let text)?: text
                case .number?, .bool?: item[field]?.jsString
                default: nil
                }
            }
            scopes.append(
                RepeatScope(
                    item: item, index: index,
                    basePath: RepeatScope.itemStatePath(path, index: index), key: key))
        }
        return RepeatRows(scopes: scopes, warnings: warnings)
    }

    /// Upstream slot warnings: `slots.default` always warns; another name warns when the
    /// component declares slots and not this one.
    public static func slotWarnings(
        id: String, type: String, slots: [String: [String]], declared: [String]
    ) -> [RenderWarning] {
        var warnings: [RenderWarning] = []
        for name in slots.keys.sorted() {
            if name == JRSlots.defaultSlot {
                warnings.append(.defaultSlot(id: id, type: type))
            } else if !declared.contains(name) {
                warnings.append(.unknownSlot(id: id, type: type, slot: name))
            }
        }
        return warnings
    }

    /// The children of an element: `children`, then `slots.default` (a synonym).
    public static func childIDs(of node: RenderPlan.Node) -> [String] {
        node.childIDs + (node.slotIDs[JRSlots.defaultSlot] ?? [])
    }

    /// The named slots of an element, without `default`.
    public static func namedSlots(of node: RenderPlan.Node) -> [String: [String]] {
        node.slotIDs.filter { $0.key != JRSlots.defaultSlot }
    }
}
