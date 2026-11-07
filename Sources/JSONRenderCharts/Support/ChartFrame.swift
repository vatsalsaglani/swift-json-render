public import JSONRenderCore
public import JSONRenderSwiftUI
public import SwiftUI

/// Everything a chart's plot needs, resolved by `ChartContainer`.
public struct ChartPlotInput {
    public let kind: ChartKind
    public let data: ChartData
    /// The y domain to draw (monotonic while streaming).
    public let yDomain: ClosedRange<Double>
    public let colors: ChartColors
    public let theme: JSONRenderTheme
    /// The highlighted x value or slice label (hover, else the committed selection).
    /// Setting it changes only the local highlight; it never writes to state.
    public let selection: Binding<String?>
    /// Commits a click on `label` (nil: empty space). Only clicks and keys write to state;
    /// a second click on the committed label deselects it.
    public let commit: @MainActor (String?) -> Void
    public let variant: ChartVariant
    public let legend: ChartLegendMode
    /// The plot height in points.
    public let height: Double
    public let isStreaming: Bool
    /// A host mark override (a `Chart`), when one is set for this chart type.
    public let markOverride: AnyView?
    /// The `tooltip` slot, when the spec fills it.
    public let tooltip: JRChildren?
    /// The `center` slot (donut, ring), when the spec fills it.
    public let center: JRChildren?
    /// The resolved props, for chart-specific values.
    public let props: [String: JSONValue?]

    public var tokens: ChartTokens { theme.charts }

    /// `true` when axes are hidden (`variant: minimal`).
    public var hidesAxes: Bool { variant == .minimal }

    /// `true` when the chart shows a legend: two or more series and `legend` not hidden.
    public var showsLegend: Bool { data.hasSeries && legend != .hidden }

    /// `true` when `label` is not the selected value while something is selected.
    public func isDimmed(_ label: String) -> Bool {
        guard let selected = selection.wrappedValue else { return false }
        return selected != label
    }

    /// The colour of a point: grey for "Other", the series colour with series, the accent
    /// otherwise.
    public func color(for point: ChartPoint) -> Color {
        if point.isOther { return colors.other }
        if data.hasSeries, let index = data.series.firstIndex(of: point.series) {
            return colors.series(index)
        }
        return colors.single
    }

    /// The series colours in series order (for `chartForegroundStyleScale`).
    public var seriesColors: [Color] { colors.palette(for: data.series) }

    /// The key a mark passes to `.foregroundStyle(by:)`: the series with series, else
    /// "Other" for the folded value and the y field name for the rest.
    public func styleKey(for point: ChartPoint) -> String {
        if data.hasSeries { return point.series }
        return point.isOther ? ChartPlotInput.otherKey : data.yField
    }

    /// The domain and colours that match `styleKey(for:)`.
    public var styleDomain: [String] {
        data.hasSeries ? data.series : [data.yField, ChartPlotInput.otherKey]
    }

    public var styleRange: [Color] {
        data.hasSeries ? seriesColors : [colors.single, colors.other]
    }

    static let otherKey = "Other"
}

/// The shared chart chrome and behaviour: data decoding (memoised), title and caption,
/// empty, skeleton and rule-message states, "Show as Table", selection write-back, arrow
/// keys, the monotonic streaming domain, styles and the accessibility summary.
///
/// Every chart component is `ChartContainer(kind:context:) { input in … }`. jr-3d's charts
/// pass their own `make` function.
public struct ChartContainer<Plot: View>: View {
    let kind: ChartKind
    let context: JRRenderContext
    let make: @Sendable ([String: JSONValue?]) -> (ChartData, [ChartWarning])
    let fixedHeight: Bool
    let summaryOverride: String?
    let plot: @MainActor (ChartPlotInput) -> Plot

    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrStreamPhase) private var phase
    @Environment(\.jrWriteBinding) private var writeBinding
    @Environment(\.jrChartStyles) private var styles
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.jrChartShowsTable) private var hostShowsTable

    @State private var cache = ChartDataCache()
    @State private var domain = MonotonicDomain()
    @State private var selection = ChartSelectionState()
    @State private var showsTable = false

    /// - Parameters:
    ///   - make: decodes props into data; default `ChartData.make(props:kind:)`.
    ///   - fixedHeight: `false` lets the plot size itself (gauge, sparkline).
    ///   - summary: a default summary that replaces `ChartSummary` (gauge).
    public init(
        kind: ChartKind, context: JRRenderContext,
        make: (@Sendable ([String: JSONValue?]) -> (ChartData, [ChartWarning]))? = nil,
        fixedHeight: Bool = true, summary: String? = nil,
        @ViewBuilder plot: @escaping @MainActor (ChartPlotInput) -> Plot
    ) {
        self.kind = kind
        self.context = context
        self.make = make ?? { props in ChartData.make(props: props, kind: kind) }
        self.fixedHeight = fixedHeight
        self.summaryOverride = summary
        self.plot = plot
    }

    private var reader: ChartPropReader { ChartPropReader(context.props) }

    private var isStreaming: Bool { context.isStreaming || phase == .streaming }

    public var body: some View {
        let data = cache.data(for: context.props, kind: kind, make: make)
        let variant: ChartVariant = reader.choice("variant", default: .default)
        let heightChoice: ChartHeight = reader.choice(
            "height", default: variant == .dense ? .compact : .regular)
        let height = heightChoice.points
        let streaming = isStreaming
        let shownDomain =
            streaming && !data.yDomainIsFixed ? (domain.current ?? data.yDomain) : data.yDomain
        let summary = reader.string("summary") ?? summaryOverride ?? ChartSummary.text(for: data)
        VStack(alignment: .leading, spacing: theme.space.s2) {
            ChartHeader(context: context, title: reader.string("title"), theme: theme)
            content(data: data, domain: shownDomain, variant: variant, height: height)
                .accessibilityChartDescriptor(
                    ChartAccessibilityDescriptor(
                        data: data, title: reader.string("title"), summary: summary)
                )
                .accessibilityLabel(summary)
            ChartCaption(
                context: context, caption: reader.string("caption"),
                stopped: phase == .stopped, theme: theme)
        }
        .font(variant == .dense ? theme.type.caption : theme.type.footnote)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .contextMenu {
            Button(showsTable ? "Show as Chart" : "Show as Table") { showsTable.toggle() }
        }
        .focusable(kind != .sparkline)
        .onKeyPress(.leftArrow) { moveSelection(-1, data: data) }
        .onKeyPress(.rightArrow) { moveSelection(1, data: data) }
        .onKeyPress(.escape) {
            let write = selection.clear()
            guard case .some = write else { return .ignored }
            perform(write, data: data)
            return .handled
        }
        .onKeyPress(characters: ["t"], phases: .down) { press in
            guard press.modifiers.contains(.command) else { return .ignored }
            showsTable.toggle()
            return .handled
        }
        .onChange(of: selectionProp, initial: true) { _, value in
            if selection.committed != value { selection.sync(fromState: value) }
        }
        .onChange(of: data.dataRange, initial: true) { _, range in
            guard streaming, let range else { return }
            domain.include(range, includeZero: kind != .scatter && kind != .sparkline)
        }
        .onChange(of: streaming) { _, now in
            if !now { domain.reset() }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: theme.motion.reveal.seconds), value: streaming)
    }

    /// The selection prop's current value as a label.
    private var selectionProp: String? {
        guard let value = reader.value("selection") else { return nil }
        return ChartValues.text(value)
    }

    private func moveSelection(_ step: Int, data: ChartData) -> KeyPress.Result {
        guard context.bindings["selection"] != nil else { return .ignored }
        perform(selection.move(by: step, in: ChartSelection.labels(in: data)), data: data)
        return .handled
    }

    /// Writes a committed selection change; `.none` writes nothing. The loop guard skips a
    /// value the state already holds.
    private func perform(_ write: String??, data: ChartData) {
        guard case .some(let value) = write, value != selectionProp else { return }
        ChartSelection.write(value, data: data, bindings: context.bindings, writer: writeBinding)
    }

    /// The highlight binding: reads the shown label, sets only the hover.
    private var highlight: Binding<String?> {
        Binding(get: { selection.shown }, set: { selection.hover($0) })
    }

    @ViewBuilder
    private func content(
        data: ChartData, domain: ClosedRange<Double>, variant: ChartVariant, height: Double
    ) -> some View {
        if let blocking = data.blocking {
            ChartMessage(text: "\(kind.rawValue): \(blocking.message)", theme: theme)
                .frame(minHeight: fixedHeight ? height : nil)
        } else if data.isEmpty, kind != .gauge {
            if isStreaming {
                ChartSkeleton(theme: theme).frame(height: fixedHeight ? height : 48)
            } else if let slot = context.slots["empty"], !slot.isEmpty {
                slot
            } else {
                ChartMessage(text: reader.string("emptyText") ?? "No data", theme: theme)
                    .frame(minHeight: fixedHeight ? height : nil)
            }
        } else if showsTable || hostShowsTable {
            ChartTableView(data: data, height: height)
        } else {
            styledPlot(data: data, domain: domain, variant: variant, height: height)
        }
    }

    @ViewBuilder
    private func styledPlot(
        data: ChartData, domain: ClosedRange<Double>, variant: ChartVariant, height: Double
    ) -> some View {
        let input = ChartPlotInput(
            kind: kind, data: data, yDomain: domain, colors: ChartColors(theme: theme),
            theme: theme, selection: highlight,
            commit: { label in perform(selection.click(label), data: data) }, variant: variant,
            legend: reader.choice("legend", default: .auto), height: height,
            isStreaming: isStreaming, markOverride: styles.marks[kind]?.make(data),
            tooltip: context.slots["tooltip"], center: context.slots["center"],
            props: context.props)
        let plot = plot(input).frame(height: fixedHeight ? height : nil)
        if let style = styles.styles[kind] {
            style.make(
                ChartStyleConfiguration(
                    kind: kind, data: data, yDomain: domain, selection: highlight,
                    tokens: theme.charts, marks: AnyView(plot), isStreaming: isStreaming))
        } else {
            plot
        }
    }
}

extension EnvironmentValues {
    /// `true` shows every chart below as a table ("Show as Table" from a host button). The
    /// context menu and ⌘T still toggle each chart on its own.
    @Entry public var jrChartShowsTable: Bool = false
}

/// Memoises `ChartData.make` per props value. Selection and chrome props are not part of
/// the key, so a selection change does not decode the data again.
@MainActor final class ChartDataCache {
    private static let chromeProps: Set<String> = [
        "selection", "summary", "title", "caption", "emptyText", "legend", "height", "variant",
    ]
    private var key: [String: JSONValue?]?
    private var kind: ChartKind?
    private var value: (ChartData, [ChartWarning])?

    func data(
        for props: [String: JSONValue?], kind: ChartKind,
        make: ([String: JSONValue?]) -> (ChartData, [ChartWarning])
    ) -> ChartData {
        let relevant = props.filter { !Self.chromeProps.contains($0.key) }
        if let value, self.kind == kind, key == relevant { return value.0 }
        let made = make(props)
        key = relevant
        self.kind = kind
        value = made
        return made.0
    }
}

/// The title: the `title` slot, else the `title` prop.
struct ChartHeader: View {
    let context: JRRenderContext
    let title: String?
    let theme: JSONRenderTheme

    var body: some View {
        if let slot = context.slots["title"], !slot.isEmpty {
            slot
        } else if let title {
            Text(title)
                .font(theme.type.bodyEmphasis)
                .foregroundStyle(theme.color.text)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

/// The caption: the `caption` slot, else the `caption` prop, plus a "stopped" note.
struct ChartCaption: View {
    let context: JRRenderContext
    let caption: String?
    let stopped: Bool
    let theme: JSONRenderTheme

    var body: some View {
        if let slot = context.slots["caption"], !slot.isEmpty {
            slot
        } else if caption != nil || stopped {
            Text(
                [caption, stopped ? "The stream stopped; the data may be incomplete." : nil]
                    .compactMap(\.self).joined(separator: " ")
            )
            .font(theme.type.caption)
            .foregroundStyle(theme.color.textSecondary)
        }
    }
}

/// A quiet message in place of the plot (no data, or a broken rule).
struct ChartMessage: View {
    let text: String
    let theme: JSONRenderTheme

    var body: some View {
        Text(text)
            .font(theme.type.caption)
            .foregroundStyle(theme.color.textSecondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(theme.space.s2)
            .background(
                RoundedRectangle(cornerRadius: theme.radius.control)
                    .strokeBorder(theme.color.hairline))
    }
}

/// The skeleton before streamed data arrives: a baseline and three ghost bars.
struct ChartSkeleton: View {
    let theme: JSONRenderTheme

    var body: some View {
        GeometryReader { proxy in
            let fill = theme.color.textMuted.opacity(0.18)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(alignment: .bottom, spacing: proxy.size.width * 0.08) {
                    ForEach([0.45, 0.8, 0.6], id: \.self) { fraction in
                        RoundedRectangle(cornerRadius: theme.charts.barCornerRadius)
                            .fill(fill)
                            .frame(height: proxy.size.height * fraction * 0.85)
                    }
                }
                .padding(.horizontal, proxy.size.width * 0.12)
                Rectangle().fill(theme.color.hairline).frame(height: 1)
            }
        }
        .accessibilityLabel("Loading chart")
    }
}

extension Duration {
    /// The duration in seconds.
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}
