// Owner: jr-3c (wave 2). Shared views for the chart pages.
import JSONRenderCharts
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

/// The chart catalog the pages render with.
enum ChartGallery {
    static let catalog: Catalog? = try? Catalog.charts
}

/// One chart variant in a card. The chart is built by the chart catalog's view factory,
/// so the page shows exactly what a spec renders. With `bindsSelection`, a click writes
/// the selected value through `jrWriteBinding`, and the card prints it.
struct ChartDemo: View {
    let title: String
    let type: String
    let props: [String: JSONValue]
    var bindsSelection = false

    @State private var picked: JSONValue = .null
    @Environment(\.jsonRenderTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space.s2) {
            Text(title)
                .font(theme.type.caption)
                .foregroundStyle(theme.color.textSecondary)
            chart
            if bindsSelection {
                Text("Selection: \(picked == .null ? "none" : picked.jsString)")
                    .font(theme.type.caption.monospacedDigit())
                    .foregroundStyle(theme.color.textSecondary)
            }
        }
        .padding(theme.space.s4)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: theme.radius.card)
                .fill(theme.color.surface)
                .strokeBorder(theme.color.hairline))
    }

    @ViewBuilder
    private var chart: some View {
        if let factory = ChartGallery.catalog?.viewFactory(for: type) {
            factory.make(context)
                .environment(
                    \.jrWriteBinding, JRBindingWriter(id: writerID) { _, value in picked = value })
        } else {
            Text("\(type) is not registered.")
        }
    }

    private var context: JRRenderContext {
        var resolved = props.mapValues { Optional($0) }
        var bindings: [String: JSONPointer] = [:]
        if bindsSelection {
            resolved["selection"] = .some(picked)
            bindings["selection"] = JSONPointer(tokens: ["picked"])
        }
        return JRRenderContext(id: title, props: resolved, bindings: bindings)
    }

    @State private var writerID = UUID()
}

/// A page: a title, a sentence, and the variants stacked.
struct ChartVariantsPage: View {
    let title: String
    let summary: String
    let demos: [ChartDemo]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title).font(.title2.weight(.semibold))
                Text(summary).foregroundStyle(.secondary)
                ForEach(Array(demos.enumerated()), id: \.offset) { _, demo in
                    demo
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
    }
}
