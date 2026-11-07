internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Stages that narrow: tests collected → run → passed. One hue, centred bars, the widest
/// first, and the step-to-step percent between rows. At most 8 stages; more fold into
/// "Other". A stage larger than the one before it is an error unless `sort` is set.
public struct Funnel: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.funnel.rawValue,
        description:
            "Stages that narrow: collected, run, passed. Each stage must not be larger than the one before it unless sort is set.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("label", "Field for the stage name. Default \"label\"."),
                ChartProps.field("value", "Field for the stage value. Default \"value\"."),
                ChartProps.choice(
                    "show", FunnelOptions.Show.allCases.map(\.rawValue),
                    "value: the value on each bar; percent: the share of the first stage; both: the value, and the step-to-step percent between rows. Default value."
                ),
                ChartProps.choice(
                    "sort", FunnelOptions.Sort.allCases.map(\.rawValue),
                    "desc sorts the stages widest first; none keeps the order and allows a larger stage. Default: keep the order and reject a larger stage."
                ),
                ChartProps.choice(
                    "align", FunnelOptions.Align.allCases.map(\.rawValue),
                    "center (default), or start (left) for a ranked bar."),
            ] + ChartProps.chrome(domains: false)),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["stage": "Collected", "n": 1296]), .object(["stage": "Ran", "n": 1284]),
                .object(["stage": "Passed", "n": 1277]),
            ]),
            "label": "stage", "value": "n", "show": "both",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .funnel, context: context, make: FunnelData.make, fixedHeight: false) {
            input in
            FunnelPlot(input: input)
        }
    }
}

/// The funnel props that are not shared chart props.
public enum FunnelOptions {
    public enum Show: String, Sendable, CaseIterable { case value, percent, both }
    public enum Sort: String, Sendable, CaseIterable { case none, desc }
    /// `left` is accepted as another name for `start`.
    public enum Align: String, Sendable, CaseIterable { case center, start, left }
}

/// The funnel arithmetic: sorting, the fold into "Other", and the percents.
public enum FunnelData {
    public static func make(props: [String: JSONValue?]) -> (ChartData, [ChartWarning]) {
        let reader = ChartPropReader(props)
        var warnings: [ChartWarning] = []
        var data = CompositeData.start(kind: .funnel, reader: reader, warnings: &warnings)
        let labelField = reader.string("label") ?? "label"
        let valueField = reader.string("value") ?? "value"
        data.xField = labelField
        data.yField = valueField
        var skipped = 0
        var stages: [(label: String, value: Double)] = []
        for fields in CompositeData.objects(reader, skipped: &skipped) {
            guard let label = ChartValues.text(fields[labelField]),
                let value = ChartValues.number(fields[valueField])
            else {
                skipped += 1
                continue
            }
            stages.append((label, max(value, 0)))
        }
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        if reader.choice("sort", default: FunnelOptions.Sort.none) == .desc {
            // A stable sort: equal stages keep their order.
            stages = stages.enumerated().sorted { lhs, rhs in
                lhs.element.value != rhs.element.value
                    ? lhs.element.value > rhs.element.value : lhs.offset < rhs.offset
            }.map(\.element)
        }
        let limit = CompositeBudgets.maxFunnelStages
        var isOther = Array(repeating: false, count: stages.count)
        if stages.count > limit {
            let rest = stages.count - (limit - 1)
            let last = stages[stages.count - 1].value
            stages = Array(stages.prefix(limit - 1)) + [("Other (\(rest))", last)]
            isOther = Array(repeating: false, count: limit - 1) + [true]
            warnings.append(.foldedIntoOther(rest))
        }
        let labels = CompositeData.unique(stages.map(\.label))
        data.points = stages.enumerated().map { index, stage in
            ChartPoint(
                id: index, x: .category(labels[index]), xLabel: labels[index], y: stage.value,
                isOther: isOther[index])
        }
        data.categories = labels
        CompositeData.finish(
            &data, range: CompositeData.extent(stages.map(\.value) + [0]), reader: reader,
            includeZero: true)
        return (data, warnings)
    }

    /// Each stage as a percent of the first stage (0 when the first is 0).
    public static func shareOfFirst(_ values: [Double]) -> [Double] {
        guard let first = values.first, first > 0 else { return values.map { _ in 0 } }
        return values.map { $0 / first * 100 }
    }

    /// The step conversion: stage `i + 1` as a percent of stage `i` (`nil` after a 0).
    public static func stepPercents(_ values: [Double]) -> [Double?] {
        zip(values, values.dropFirst()).map { previous, next in
            previous > 0 ? next / previous * 100 : nil
        }
    }

    /// The index of the first stage larger than the stage before it, or `nil`.
    public static func firstIncrease(_ values: [Double]) -> Int? {
        zip(values, values.dropFirst()).enumerated().first { $0.element.1 > $0.element.0 }
            .map { $0.offset + 1 }
    }
}

/// The default funnel plot: horizontal bars, centred by default.
struct FunnelPlot: View {
    let input: ChartPlotInput

    private static let rowHeight = 34.0

    var body: some View {
        let values = input.data.points.map(\.y)
        if ChartPropReader(input.props).value("sort") == nil,
            let index = FunnelData.firstIncrease(values)
        {
            ChartMessage(
                text:
                    "Funnel: stage \(index + 1) is larger than the stage before it; set sort: \"none\" to allow it.",
                theme: input.theme
            )
            .frame(minHeight: input.height)
        } else {
            chart(values: values)
                .frame(height: max(input.height, Double(values.count) * Self.rowHeight))
        }
    }

    private var show: FunnelOptions.Show {
        ChartPropReader(input.props).choice("show", default: .value)
    }

    private var centred: Bool {
        ChartPropReader(input.props).choice("align", default: FunnelOptions.Align.center) == .center
    }

    private func chart(values: [Double]) -> some View {
        let data = input.data
        let widest = values.max() ?? 1
        let shares = FunnelData.shareOfFirst(values)
        let steps = FunnelData.stepPercents(values)
        let reach = max(widest, 1e-9) * (centred ? 0.62 : 1.22)
        return Chart {
            ForEach(Array(data.points.enumerated()), id: \.element.id) { index, point in
                bar(point)
                    .foregroundStyle(point.isOther ? input.colors.other : input.colors.single)
                    .cornerRadius(input.tokens.barCornerRadius + 1)
                    .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                    .accessibilityLabel(label(point, share: shares[index]))
                    .annotation(position: .trailing, spacing: 6) {
                        Text(barText(point, share: shares[index]))
                            .font(input.tokens.axisFont.monospacedDigit())
                            .foregroundStyle(input.theme.color.text)
                    }
                    .annotation(position: .bottom, spacing: 1) {
                        if show == .both, index < steps.count, let step = steps[index] {
                            Text(ChartValueFormat.percent.axisString(step))
                                .font(input.tokens.axisFont.monospacedDigit())
                                .foregroundStyle(input.theme.color.textMuted)
                                .accessibilityHidden(true)
                        }
                    }
            }
        }
        .jrMarkOverride(input)
        .chartXScale(domain: (centred ? -reach : 0)...reach)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading) { _ in
                AxisValueLabel().font(input.tokens.axisFont)
            }
        }
        .chartYAxis(input.hidesAxes ? .hidden : .automatic)
        .chartLegend(.hidden)
        .jrPointerSelection(input, axis: .y)
    }

    private func bar(_ point: ChartPoint) -> BarMark {
        let low = centred ? -point.y / 2 : 0
        let high = centred ? point.y / 2 : point.y
        return BarMark(
            xStart: .value(input.data.yField, low), xEnd: .value(input.data.yField, high),
            y: .value(input.data.xField, point.xLabel), height: .ratio(0.55))
    }

    private func barText(_ point: ChartPoint, share: Double) -> String {
        show == .percent
            ? ChartValueFormat.percent.axisString(share) : input.data.format.axisString(point.y)
    }

    private func label(_ point: ChartPoint, share: Double) -> String {
        "\(point.xLabel), \(input.data.text(point.y)), \(ChartValueFormat.percent.axisString(share)) of the first stage"
    }
}
