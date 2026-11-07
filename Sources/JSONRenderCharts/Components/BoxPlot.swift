internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// A distribution per group: the box spans the quartiles (accent at 30 %), the median is a
/// 2 pt rule, the whiskers are hairlines to the last value within 1.5 IQR, and outliers are
/// 4 pt points. Rows give raw `values` or precomputed `{min, q1, median, q3, max,
/// outliers}`. At most 20 groups.
public struct BoxPlot: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.boxPlot.rawValue,
        description:
            "A distribution per group: suite durations, latency per backend. Each row has a values array, or precomputed min, q1, median, q3, max and outliers. At most 20 groups.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("group", "Field for the group name. Default \"group\"."),
                ChartProps.field(
                    "values", "Field for the raw numbers of a row. Default \"values\".",
                    optional: true),
                ChartProps.choice(
                    "orientation", ChartOptions.Orientation.allCases.map(\.rawValue),
                    "Default vertical."),
                PropSchema.Field(
                    name: "showOutliers", schema: PropSchema.boolean.optional(),
                    description:
                        "Default true. false draws the whiskers to the smallest and largest value and no points."
                ),
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["suite": "Canvas", "values": .array([1.2, 1.8, 2.4, 3.1, 9.5])]),
                .object([
                    "suite": "MDX", "min": 0.4, "q1": 0.7, "median": 0.9, "q3": 1.2, "max": 1.7,
                ]),
            ]),
            "group": "suite", "unit": "s",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .boxPlot, context: context, make: BoxPlotData.make) { input in
            BoxPlotPlot(input: input)
        }
    }
}

/// The five numbers and the outliers of one group.
public struct BoxPlotStats: Sendable, Hashable {
    /// The low whisker end: the smallest value within `q1 − 1.5 IQR`.
    public var low: Double
    public var q1: Double
    public var median: Double
    public var q3: Double
    /// The high whisker end: the largest value within `q3 + 1.5 IQR`.
    public var high: Double
    public var outliers: [Double]

    public init(
        low: Double, q1: Double, median: Double, q3: Double, high: Double, outliers: [Double] = []
    ) {
        self.low = low
        self.q1 = q1
        self.median = median
        self.q3 = q3
        self.high = high
        self.outliers = outliers
    }

    /// The statistics of `values` (non-finite values are ignored), or `nil` when none is
    /// left.
    ///
    /// Quartiles use **Tukey's hinges**: sort the values; the median is the middle value
    /// (or the mean of the two middle values); the lower hinge is the median of the lower
    /// half and the upper hinge the median of the upper half, where both halves include the
    /// median when the count is odd. The whiskers reach the most extreme values inside the
    /// fences `q1 − 1.5 IQR` and `q3 + 1.5 IQR`; values outside are outliers. With
    /// `outliers: false` the whiskers reach the minimum and maximum.
    public static func tukey(_ values: [Double], outliers withOutliers: Bool = true)
        -> BoxPlotStats?
    {
        let sorted = values.filter(\.isFinite).sorted()
        guard let first = sorted.first, let last = sorted.last else { return nil }
        let count = sorted.count
        let half = (count + 1) / 2  // includes the median when the count is odd
        let q1 = median(sorted[0..<half])
        let q3 = median(sorted[(count - half)..<count])
        let middle = median(sorted[0..<count])
        guard withOutliers else {
            return BoxPlotStats(low: first, q1: q1, median: middle, q3: q3, high: last)
        }
        let reach = 1.5 * (q3 - q1)
        let lowFence = q1 - reach
        let highFence = q3 + reach
        let inside = sorted.filter { $0 >= lowFence && $0 <= highFence }
        return BoxPlotStats(
            low: inside.first ?? q1, q1: q1, median: middle, q3: q3, high: inside.last ?? q3,
            outliers: sorted.filter { $0 < lowFence || $0 > highFence })
    }

    private static func median(_ slice: ArraySlice<Double>) -> Double {
        let count = slice.count
        let start = slice.startIndex
        if count % 2 == 1 { return slice[start + count / 2] }
        return (slice[start + count / 2 - 1] + slice[start + count / 2]) / 2
    }

    /// The point rows of one group, in drawing order.
    static let rowNames = ["low", "q1", "median", "q3", "high"]
    static let outlierRow = "outlier"
}

/// Box plot data. Each group becomes five points (rows `low`, `q1`, `median`, `q3`, `high`)
/// and one point per outlier (row `outlier`), so "Show as Table" and VoiceOver read every
/// number.
public enum BoxPlotData {
    public static func make(props: [String: JSONValue?]) -> (ChartData, [ChartWarning]) {
        let reader = ChartPropReader(props)
        var warnings: [ChartWarning] = []
        var data = CompositeData.start(kind: .boxPlot, reader: reader, warnings: &warnings)
        let groupField = reader.string("group") ?? "group"
        let valuesField = reader.string("values") ?? "values"
        let showOutliers = reader.bool("showOutliers") ?? true
        data.xField = groupField
        data.yField = reader.string("unit") ?? "value"
        data.options.orientation = reader.choice("orientation", default: .vertical)
        var skipped = 0
        var groups: [(String, BoxPlotStats)] = []
        for fields in CompositeData.objects(reader, skipped: &skipped) {
            guard let name = ChartValues.text(fields[groupField]),
                let stats = stats(fields, valuesField: valuesField, outliers: showOutliers)
            else {
                skipped += 1
                continue
            }
            groups.append((name, stats))
        }
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        let labels = CompositeData.unique(groups.map(\.0))
        var points: [ChartPoint] = []
        for (index, group) in groups.enumerated() {
            let label = labels[index]
            let stats = group.1
            let five = [stats.low, stats.q1, stats.median, stats.q3, stats.high]
            for (row, value) in zip(BoxPlotStats.rowNames, five) {
                points.append(
                    ChartPoint(
                        id: points.count, x: .category(label), xLabel: label, y: value, row: row))
            }
            for value in stats.outliers {
                points.append(
                    ChartPoint(
                        id: points.count, x: .category(label), xLabel: label, y: value,
                        row: BoxPlotStats.outlierRow))
            }
        }
        data.points = points
        data.categories = labels
        data.rows = points.isEmpty ? [] : BoxPlotStats.rowNames + [BoxPlotStats.outlierRow]
        CompositeData.finish(
            &data, range: CompositeData.extent(points.map(\.y)), reader: reader,
            includeZero: false)
        return (data, warnings)
    }

    /// The statistics of one row: raw values, else a complete precomputed set in order.
    static func stats(_ fields: [String: JSONValue], valuesField: String, outliers: Bool)
        -> BoxPlotStats?
    {
        if let raw = fields[valuesField]?.arrayValue {
            return BoxPlotStats.tukey(raw.compactMap(ChartValues.number), outliers: outliers)
        }
        let five = ["min", "q1", "median", "q3", "max"].compactMap {
            ChartValues.number(fields[$0])
        }
        guard five.count == 5, five == five.sorted() else { return nil }
        let extra =
            outliers ? (fields["outliers"]?.arrayValue ?? []).compactMap(ChartValues.number) : []
        return BoxPlotStats(
            low: five[0], q1: five[1], median: five[2], q3: five[3], high: five[4], outliers: extra)
    }

    /// The groups of drawn data, back from the points (a cheap pass in the plot).
    static func groups(in data: ChartData) -> [(label: String, stats: BoxPlotStats)] {
        var order: [String] = []
        var values: [String: [String: Double]] = [:]
        var outliers: [String: [Double]] = [:]
        for point in data.points {
            if values[point.xLabel] == nil {
                order.append(point.xLabel)
                values[point.xLabel] = [:]
            }
            if point.row == BoxPlotStats.outlierRow {
                outliers[point.xLabel, default: []].append(point.y)
            } else if let row = point.row {
                values[point.xLabel]?[row] = point.y
            }
        }
        return order.compactMap { label in
            guard let five = values[label], let low = five["low"], let q1 = five["q1"],
                let median = five["median"], let q3 = five["q3"], let high = five["high"]
            else { return nil }
            return (
                label,
                BoxPlotStats(
                    low: low, q1: q1, median: median, q3: q3, high: high,
                    outliers: outliers[label] ?? [])
            )
        }
    }
}

/// The default box plot.
struct BoxPlotPlot: View {
    let input: ChartPlotInput

    private var horizontal: Bool { input.data.options.orientation == .horizontal }

    var body: some View {
        let groups = BoxPlotData.groups(in: input.data)
        if groups.count > CompositeBudgets.maxBoxPlotGroups {
            ChartMessage(
                text:
                    "BoxPlot: \(groups.count) groups; the limit is \(CompositeBudgets.maxBoxPlotGroups).",
                theme: input.theme)
        } else {
            chart(groups)
        }
    }

    private func chart(_ groups: [(label: String, stats: BoxPlotStats)]) -> some View {
        let accent = input.colors.single
        let hairline = StrokeStyle(lineWidth: 1)
        return Chart {
            ForEach(groups, id: \.label) { group in
                let stats = group.stats
                let dimmed = input.isDimmed(group.label) ? 0.35 : 1
                span(group.label, from: stats.low, to: stats.q1)
                    .foregroundStyle(accent).lineStyle(hairline).opacity(dimmed)
                span(group.label, from: stats.q3, to: stats.high)
                    .foregroundStyle(accent).lineStyle(hairline).opacity(dimmed)
                tick(group.label, at: stats.low, thickness: 1, length: 0.22)
                    .foregroundStyle(accent).opacity(dimmed)
                tick(group.label, at: stats.high, thickness: 1, length: 0.22)
                    .foregroundStyle(accent).opacity(dimmed)
                box(group.label, stats)
                    .foregroundStyle(accent.opacity(0.3))
                    .cornerRadius(input.tokens.barCornerRadius)
                    .opacity(dimmed)
                    .accessibilityLabel(label(group.label, stats))
                tick(group.label, at: stats.median, thickness: 2, length: 0.5)
                    .foregroundStyle(accent).opacity(dimmed)
                ForEach(Array(stats.outliers.enumerated()), id: \.offset) { _, value in
                    outlier(group.label, value)
                        .foregroundStyle(accent)
                        .symbolSize(input.tokens.pointSize * input.tokens.pointSize)
                        .opacity(dimmed)
                        .accessibilityLabel(
                            "\(group.label), outlier, \(input.data.text(value))")
                }
            }
            ReferenceLineMarks(input, horizontal: horizontal)
        }
        .jrMarkOverride(input)
        .jrCompositeAxes(input, horizontal: horizontal)
        .chartLegend(.hidden)
        .jrCategorySelection(input, horizontal: horizontal)
    }

    private var valueName: String { input.data.yField }
    private var groupName: String { input.data.xField }

    /// A whisker from `low` to `high`.
    private func span(_ group: String, from low: Double, to high: Double) -> RuleMark {
        horizontal
            ? RuleMark(
                xStart: .value(valueName, low), xEnd: .value(valueName, high),
                y: .value(groupName, group))
            : RuleMark(
                x: .value(groupName, group), yStart: .value(valueName, low),
                yEnd: .value(valueName, high))
    }

    /// A rule across the group at `value` (median, whisker caps).
    private func tick(_ group: String, at value: Double, thickness: CGFloat, length: CGFloat)
        -> RectangleMark
    {
        horizontal
            ? RectangleMark(
                x: .value(valueName, value), y: .value(groupName, group),
                width: .fixed(thickness), height: .ratio(length))
            : RectangleMark(
                x: .value(groupName, group), y: .value(valueName, value),
                width: .ratio(length), height: .fixed(thickness))
    }

    private func box(_ group: String, _ stats: BoxPlotStats) -> BarMark {
        horizontal
            ? BarMark(
                xStart: .value(valueName, stats.q1), xEnd: .value(valueName, stats.q3),
                y: .value(groupName, group), height: .ratio(0.5))
            : BarMark(
                x: .value(groupName, group), yStart: .value(valueName, stats.q1),
                yEnd: .value(valueName, stats.q3), width: .ratio(0.5))
    }

    private func outlier(_ group: String, _ value: Double) -> PointMark {
        horizontal
            ? PointMark(x: .value(valueName, value), y: .value(groupName, group))
            : PointMark(x: .value(groupName, group), y: .value(valueName, value))
    }

    private func label(_ group: String, _ stats: BoxPlotStats) -> String {
        let text = { (value: Double) in input.data.text(value) }
        var parts = [
            group, "median \(text(stats.median))",
            "quartiles \(text(stats.q1)) to \(text(stats.q3))",
            "whiskers \(text(stats.low)) to \(text(stats.high))",
        ]
        if !stats.outliers.isEmpty { parts.append("\(stats.outliers.count) outliers") }
        return parts.joined(separator: ", ")
    }
}
