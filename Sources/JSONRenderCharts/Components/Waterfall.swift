internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// How a total is built from increases and decreases. Each step floats from where the last
/// one ended; totals and subtotals stand on the baseline in grey. Increases take the accent,
/// decreases the warning hue, and every value carries a sign, so colour is never the only
/// signal. More than 12 steps fold into "Other".
public struct Waterfall: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.waterfall.rawValue,
        description:
            "How a total is built from increases and decreases: memory by subsystem, time by phase. Rows named in subtotals show the running total from the baseline.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("label", "Field for the step label. Default \"label\"."),
                ChartProps.field(
                    "value", "Field for the change (signed). Default \"value\"."),
                PropSchema.Field(
                    name: "start", schema: PropSchema.number.optional(),
                    description: "The running total before the first row; drawn as a Start bar."),
                PropSchema.Field(
                    name: "subtotals", schema: PropSchema.array(.string).optional(),
                    description:
                        "Labels of rows drawn as the running total from the baseline. A first-row subtotal sets the start from its value."
                ),
                ChartProps.choice(
                    "orientation", ChartOptions.Orientation.allCases.map(\.rawValue),
                    "Default vertical."),
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["label": "Start", "value": 112]),
                .object(["label": "Terminals", "value": 32]),
                .object(["label": "Pool cap", "value": -24]),
                .object(["label": "Now", "value": 0]),
            ]),
            "label": "label", "value": "value", "subtotals": .array(["Start", "Now"]),
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .waterfall, context: context, make: WaterfallData.make) { input in
            WaterfallPlot(input: input)
        }
    }
}

/// The waterfall arithmetic: running totals, subtotals and the fold into "Other".
///
/// Each drawn point spans `base...base + y`. A step's `y` is its signed change and its
/// `base` the running total before it; a total's `y` is the running total and its `base` 0.
/// Totals have the series `"Total"`, steps `"Change"`.
public enum WaterfallData {
    public static let totalSeries = "Total"
    public static let changeSeries = "Change"

    /// One input row: a label and a value, and whether it is a subtotal.
    struct Row: Equatable {
        var label: String
        var value: Double
        var isTotal: Bool
        var isOther = false
    }

    public static func make(props: [String: JSONValue?]) -> (ChartData, [ChartWarning]) {
        let reader = ChartPropReader(props)
        var warnings: [ChartWarning] = []
        var data = CompositeData.start(kind: .waterfall, reader: reader, warnings: &warnings)
        let labelField = reader.string("label") ?? "label"
        let valueField = reader.string("value") ?? "value"
        data.xField = labelField
        data.yField = valueField
        data.options.orientation = reader.choice("orientation", default: .vertical)
        let subtotals = Set((reader.array("subtotals") ?? []).compactMap(\.stringValue))
        var skipped = 0
        var rows: [Row] = []
        for fields in CompositeData.objects(reader, skipped: &skipped) {
            guard let label = ChartValues.text(fields[labelField]) else {
                skipped += 1
                continue
            }
            let isTotal = subtotals.contains(label)
            guard let value = ChartValues.number(fields[valueField]) ?? (isTotal ? 0 : nil) else {
                skipped += 1
                continue
            }
            rows.append(Row(label: label, value: value, isTotal: isTotal))
        }
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        let start = reader.number("start")
        if let start, rows.first?.isTotal != true {
            rows.insert(Row(label: "Start", value: start, isTotal: true), at: 0)
        }
        let folded = fold(rows, limit: CompositeBudgets.maxWaterfallSteps)
        if folded.count < rows.count {
            warnings.append(.foldedIntoOther(rows.count - folded.count + 1))
        }
        let labels = CompositeData.unique(folded.map(\.label))
        data.points = points(folded, labels: labels, start: start ?? 0)
        data.categories = labels
        let ends: [Double] = data.points.flatMap { point -> [Double] in
            let base = point.base ?? 0
            return [base, base + point.y]
        }
        CompositeData.finish(
            &data, range: CompositeData.extent(ends + [0]), reader: reader, includeZero: true)
        return (data, warnings)
    }

    /// The drawn points. A subtotal shows the running total; a subtotal before any change
    /// sets the running total from its own value (`Start: 112`).
    static func points(_ rows: [Row], labels: [String], start: Double) -> [ChartPoint] {
        var running = start
        var seenChange = false
        var points: [ChartPoint] = []
        for (index, row) in rows.enumerated() {
            let label = labels[index]
            if row.isTotal {
                if !seenChange { running = row.value }
                points.append(
                    ChartPoint(
                        id: index, x: .category(label), xLabel: label, y: running,
                        series: totalSeries, base: 0))
            } else {
                seenChange = true
                points.append(
                    ChartPoint(
                        id: index, x: .category(label), xLabel: label, y: row.value,
                        series: changeSeries, isOther: row.isOther, base: running))
                running += row.value
            }
        }
        return points
    }

    /// At most `limit` rows. Changes after the first `limit − 2` rows fold into one
    /// "Other (n)" change (their sum); a final subtotal stays last. Subtotals inside the
    /// folded part are dropped: the running total after "Other" is the same.
    static func fold(_ rows: [Row], limit: Int) -> [Row] {
        guard rows.count > limit, limit >= 3 else { return rows }
        let keepsLast = rows.last?.isTotal == true
        let tailCount = keepsLast ? 1 : 0
        let head = Array(rows.prefix(limit - 1 - tailCount))
        let middle = rows[head.count..<(rows.count - tailCount)]
        let changes = middle.filter { !$0.isTotal }
        var result = head
        if !changes.isEmpty {
            result.append(
                Row(
                    label: "Other (\(changes.count))", value: changes.reduce(0) { $0 + $1.value },
                    isTotal: false, isOther: true))
        }
        if keepsLast, let last = rows.last { result.append(last) }
        return result
    }
}

/// The geometry of the waterfall connectors, in band units: category `i` is centred at `i`
/// and one category step is 1.
enum WaterfallConnectors {
    /// The bar width as a share of the category step.
    static let barRatio = 0.62

    /// One connector: from `start` to `end` (band units) at the value `level`.
    struct Segment: Sendable, Hashable {
        let start: Double
        let end: Double
        let level: Double
    }

    /// The connector from each bar to the next, at the running total after the first of
    /// the two (`levels[i]`), from the far edge of bar `i` to the near edge of bar `i + 1`.
    static func segments(levels: [Double], barRatio: Double = barRatio) -> [Segment] {
        let half = barRatio / 2
        return levels.indices.dropLast().map { index in
            Segment(
                start: Double(index) + half, end: Double(index + 1) - half, level: levels[index])
        }
    }
}

/// The default waterfall plot.
struct WaterfallPlot: View {
    let input: ChartPlotInput

    private var horizontal: Bool { input.data.options.orientation == .horizontal }

    var body: some View {
        let data = input.data
        let points = data.points
        Chart {
            ForEach(points) { point in
                bar(point)
                    .foregroundStyle(color(point))
                    .cornerRadius(input.tokens.barCornerRadius)
                    .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                    .accessibilityLabel(label(point))
                    .annotation(position: annotationPosition(point), spacing: 3) {
                        Text(valueText(point))
                            .font(input.tokens.axisFont.monospacedDigit())
                            .foregroundStyle(input.theme.color.textSecondary)
                    }
            }
            ReferenceLineMarks(input, horizontal: horizontal)
        }
        .jrMarkOverride(input)
        .jrValueAxes(input, horizontal: horizontal, aligned: true)
        // Hairline connectors behind the marks, from the edge of one bar to the edge of the
        // next at the running total. Decoration only: no accessibility element.
        .chartBackground { proxy in
            GeometryReader { geometry in
                connectors(proxy: proxy, geometry: geometry, points: points)
                    .stroke(input.theme.color.textMuted, lineWidth: 0.5)
            }
            .accessibilityHidden(true)
        }
        .chartLegend(.hidden)
        .jrCategorySelection(input, horizontal: horizontal)
    }

    private func bar(_ point: ChartPoint) -> BarMark {
        let base = point.base ?? 0
        let low = PlottableValue.value(input.data.yField, min(base, base + point.y))
        let high = PlottableValue.value(input.data.yField, max(base, base + point.y))
        let category = PlottableValue.value(input.data.xField, point.xLabel)
        return horizontal
            ? BarMark(
                xStart: low, xEnd: high, y: category, height: .ratio(WaterfallConnectors.barRatio))
            : BarMark(
                x: category, yStart: low, yEnd: high, width: .ratio(WaterfallConnectors.barRatio))
    }

    /// The connector path in plot coordinates. Band units map to points through the first
    /// two category centres (a category scale has a uniform step).
    private func connectors(proxy: ChartProxy, geometry: GeometryProxy, points: [ChartPoint])
        -> Path
    {
        var path = Path()
        guard let anchor = proxy.plotFrame, points.count > 1 else { return path }
        let frame = geometry[anchor]
        let labels = points.map(\.xLabel)
        func centre(_ label: String) -> CGFloat? {
            horizontal ? proxy.position(forY: label) : proxy.position(forX: label)
        }
        func level(_ value: Double) -> CGFloat? {
            horizontal ? proxy.position(forX: value) : proxy.position(forY: value)
        }
        guard let first = centre(labels[0]), let second = centre(labels[1]) else { return path }
        let step = second - first
        let segments = WaterfallConnectors.segments(
            levels: points.map { ($0.base ?? 0) + $0.y })
        for segment in segments {
            guard let at = level(segment.level) else { continue }
            let start = first + step * segment.start
            let end = first + step * segment.end
            if horizontal {
                path.move(to: CGPoint(x: frame.minX + at, y: frame.minY + start))
                path.addLine(to: CGPoint(x: frame.minX + at, y: frame.minY + end))
            } else {
                path.move(to: CGPoint(x: frame.minX + start, y: frame.minY + at))
                path.addLine(to: CGPoint(x: frame.minX + end, y: frame.minY + at))
            }
        }
        return path
    }

    private func isTotal(_ point: ChartPoint) -> Bool { point.series == WaterfallData.totalSeries }

    private func color(_ point: ChartPoint) -> Color {
        if isTotal(point) { return input.colors.other }
        return point.y < 0 ? input.colors.roles.warning : input.colors.single
    }

    private func valueText(_ point: ChartPoint) -> String {
        isTotal(point)
            ? input.data.format.axisString(point.y)
            : CompositeData.signed(point.y, format: input.data.format)
    }

    /// Increases and totals are labelled past their high end, decreases past their low end.
    private func annotationPosition(_ point: ChartPoint) -> AnnotationPosition {
        let down = !isTotal(point) && point.y < 0
        if horizontal { return down ? .leading : .trailing }
        return down ? .bottom : .top
    }

    private func label(_ point: ChartPoint) -> String {
        let kind = isTotal(point) ? "total" : (point.y < 0 ? "decrease" : "increase")
        return "\(point.xLabel), \(kind), \(input.data.text(point.y))"
    }
}
