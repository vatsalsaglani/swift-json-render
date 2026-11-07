// Owner: jr-3 (wave 2). One element by id: dangling, too deep, cycle, or resolved.
internal import JSONRenderCore
internal import SwiftUI

/// Draws the element `id` of the enclosing `JSONRenderView`.
struct ElementView: View {
    let id: String
    @Environment(\.jrRenderModel) private var model

    var body: some View {
        if let child = JRRepeatRows.parse(id) {
            RepeatRowView(child: child)
        } else if let model {
            ElementBody(id: id, model: model)
        }
    }
}

/// Picks what to draw for a known id.
private struct ElementBody: View {
    let id: String
    let model: RenderModel
    @Environment(\.jrStreamPhase) private var phase
    @Environment(\.jrAncestors) private var ancestors

    var body: some View {
        if ancestors.contains(id) {
            JRFallbackBlock(reason: "Cycle", symbol: "arrow.triangle.2.circlepath")
                .onAppear { model.record(.cycle(id: id)) }
        } else if let node = model.plan.nodes[id], let element = model.spec.elements[id] {
            if model.plan.truncatedAtDepth.contains(id) {
                JRFallbackBlock(reason: "Too deep", symbol: "arrow.down.to.line")
                    .onAppear { model.record(.tooDeep(id: id)) }
            } else {
                ResolvedElementView(id: id, node: node, element: element, model: model)
            }
        } else {
            DanglingView(id: id, phase: phase, model: model)
        }
    }
}

/// An id with no element: a skeleton while streaming, a caption after a stop, otherwise a
/// fallback block (journaled once).
private struct DanglingView: View {
    let id: String
    let phase: JRStreamPhase
    let model: RenderModel
    @Environment(\.jsonRenderTheme) private var theme

    var body: some View {
        switch phase {
        case .streaming:
            JRSkeletonPlaceholder(shape: .line)
        case .stopped:
            Text("Stopped")
                .font(theme.type.caption)
                .foregroundStyle(theme.color.textSecondary)
        case .idle, .final:
            JRFallbackBlock(reason: "Missing element", symbol: "questionmark.square.dashed")
                .onAppear { model.record(.missingElement(id: id)) }
        }
    }
}
