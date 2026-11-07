// Owner: jr-3 (wave 2). Resolves one element and hands its context to the catalog factory.
internal import JSONRenderCore
internal import SwiftUI
internal import os

/// Resolves props, bindings and visibility, builds the `JRRenderContext` and calls the
/// catalog's `ViewFactory` (the only renderer lookup). An unknown type draws a fallback
/// block. The element's effective theme, repeat rows, events and watchers apply here.
struct ResolvedElementView: View {
    let id: String
    let node: RenderPlan.Node
    let element: UIElement
    let model: RenderModel

    @Environment(\.jrRepeatScope) private var scope
    @Environment(\.jrStreamPhase) private var phase
    @Environment(\.jrAncestors) private var ancestors
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jsonRenderTypeThemes) private var typeThemes
    @Environment(\.jsonRenderThemeTokens) private var tokens
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let resolved = RenderSignpost.element {
            ElementResolution.resolve(
                element: element, scope: scope, state: model.stateSnapshot.state,
                catalog: model.catalog)
        }
        let _ = record(resolved.warnings.map { .resolution(id: id, $0) })
        // Watchers run whether the element is visible and whether its type is known, as
        // upstream: the watch task wraps every branch, so it lives while the element is in
        // the plan.
        if let watch = element.watch, !watch.isEmpty {
            branches(resolved, watched: true)
                .modifier(WatchHost(id: id, watch: watch, scope: scope, model: model))
        } else {
            branches(resolved, watched: false)
        }
    }

    @ViewBuilder
    private func branches(_ resolved: ResolvedElement, watched: Bool) -> some View {
        if resolved.isVisible {
            if let factory = model.catalog.viewFactory(for: node.type) {
                component(factory, resolved)
            } else {
                JRFallbackBlock(reason: node.type, symbol: "puzzlepiece.extension")
                    .onAppear { model.record(.unknownType(id: id, type: node.type)) }
            }
        } else if watched {
            // A hidden element draws nothing, but an empty view never appears, so its task
            // would never start. A zero-size, hidden carrier holds the watch task. In a
            // stack it takes one spacing gap; only hidden elements with `watch` pay it.
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func component(_ factory: ViewFactory, _ resolved: ResolvedElement) -> some View {
        let _ = record(
            ElementResolution.slotWarnings(
                id: id, type: node.type, slots: node.slotIDs,
                declared: model.catalog.component(named: node.type)?.slots ?? []))
        let rows = repeatRows(resolved)
        let context = JRRenderContext(
            id: id, props: resolved.props, bindings: resolved.bindings,
            children: JRChildren(ids: rows?.flatIDs ?? ElementResolution.childIDs(of: node)),
            slots: ElementResolution.namedSlots(of: node).mapValues { JRChildren(ids: $0) },
            scope: scope,
            emit: { [model, id, scope] event, payload in
                _ = model.emit(id: id, event: event, payload: payload, scope: scope)
            },
            isStreaming: phase == .streaming)
        let view = factory.make(context)
            .environment(\.jrRepeatRows, rows)
            .environment(\.jrElementEvents, Set((element.on ?? [:]).keys))
            .environment(\.jrAncestors, ancestors.union([id]))
            .environment(
                \.jsonRenderTheme,
                theme.effective(
                    forType: node.type, typeThemes: typeThemes, tokens: tokens,
                    contrast: contrast)
            )
            // The reveal fades only while streaming: elsewhere it reads a theme with no
            // motion, so a static spec appears at once. Always applied, so the view identity
            // does not change when the stream ends.
            .jrStreamReveal()
            .environment(\.jsonRenderTheme, phase == .streaming ? theme : revealFree)
        view
    }

    private var revealFree: JSONRenderTheme {
        var copy = theme
        copy.motion = .none
        return copy
    }

    private func repeatRows(_ resolved: ResolvedElement) -> JRRepeatRows? {
        guard element.repeat != nil else { return nil }
        let rows = ElementResolution.repeatRows(
            element: element, id: id, scope: scope, state: model.stateSnapshot.state,
            itemFilter: resolved.itemFilter, limits: model.limits)
        record(rows.warnings)
        return JRRepeatRows(
            elementID: id, scopes: rows.scopes, childIDs: ElementResolution.childIDs(of: node))
    }

    private func record(_ warnings: [RenderWarning]) {
        for warning in warnings { model.record(warning) }
    }
}

/// Signposts for Instruments: `jsonrender.render.element` around each resolution.
enum RenderSignpost {
    static let signposter = OSSignposter(subsystem: "swift-json-render", category: "render")

    static func element<T>(_ body: () -> T) -> T {
        signposter.withIntervalSignpost("jsonrender.render.element") { body() }
    }
}
