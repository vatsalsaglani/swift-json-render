internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Parts of one whole, two to six parts: pie or donut, largest first, the rest folded into
/// "Other". No exploded slices, no 3D. The legend prints each value, so colour is never the
/// only signal. One slice renders as a single value.
public struct PieChart: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.pie.rawValue,
        description:
            "Parts of one whole, 2 to 6 parts. Slices after maxSlices fold into Other. Negative values are rejected: use BarChart.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("label", "Field for the slice label."),
                ChartProps.field("value", "Field for the slice value (not negative)."),
                PropSchema.Field(
                    name: "donut", schema: PropSchema.boolean.optional(),
                    description: "A ring with room for a centre text."),
                PropSchema.Field(
                    name: "center",
                    schema: PropSchema.union([
                        .string,
                        .object([
                            .init(name: "value", schema: .string),
                            .init(name: "label", schema: PropSchema.string.optional()),
                        ]),
                    ]).optional(),
                    description: "Donut centre: text, { value, label } or a $template."),
                PropSchema.Field(
                    name: "maxSlices", schema: PropSchema.number.optional(),
                    description: "Slices shown, Other included. Default 6, at most 12."),
            ] + ChartProps.chrome(domains: false)),
        slots: ChartProps.slots + ["center"],
        example: [
            "data": .array([
                .object(["part": "Terminals", "mb": 61]), .object(["part": "Editor", "mb": 36]),
            ]),
            "label": "part", "value": "mb", "donut": true,
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .pie, context: context) { input in
            PieChartPlot(input: input)
        }
    }
}

struct PieChartPlot: View {
    let input: ChartPlotInput

    @State private var angle: Double?

    private var colors: [Color] {
        input.data.points.enumerated().map { index, point in
            point.isOther ? input.colors.other : input.colors.series(index)
        }
    }

    var body: some View {
        if input.data.points.count == 1, let only = input.data.points.first {
            SingleValueView(input: input, point: only)
        } else {
            HStack(alignment: .center, spacing: input.theme.space.s4) {
                chart
                    .frame(width: input.height, height: input.height)
                if input.legend != .hidden {
                    PieLegend(input: input, colors: colors)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var chart: some View {
        let data = input.data
        let donut = data.options.donut
        return Chart {
            ForEach(data.points) { point in
                SectorMark(
                    angle: .value(data.yField, point.y),
                    innerRadius: .ratio(donut ? 0.62 : 0),
                    angularInset: input.tokens.sliceGap
                )
                .foregroundStyle(by: .value("Slice", point.xLabel))
                .cornerRadius(donut ? 2 : 0)
                .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
            }
        }
        .jrMarkOverride(input)
        .chartForegroundStyleScale(domain: data.points.map(\.xLabel), range: colors)
        .chartLegend(.hidden)
        .chartAngleSelection(value: $angle)
        .onChange(of: angle) { _, value in
            input.selection.wrappedValue = value.flatMap(sliceLabel(at:))
        }
        .overlay {
            if donut { PieCenter(input: input) }
        }
    }

    /// The slice that holds the cumulative `value` on the angle scale.
    private func sliceLabel(at value: Double) -> String? {
        var running = 0.0
        for point in input.data.points {
            running += point.y
            if value <= running { return point.xLabel }
        }
        return input.data.points.last?.xLabel
    }
}

/// The donut centre: the `center` slot, else the `center` prop (text or `{ value, label }`).
struct PieCenter: View {
    let input: ChartPlotInput

    var body: some View {
        if let slot = input.center, !slot.isEmpty {
            slot
        } else {
            let center = input.props["center"] ?? nil
            let value = center?.stringValue ?? center?["value"].flatMap(ChartValues.text)
            let label = center?["label"]?.stringValue
            if let value {
                VStack(spacing: 0) {
                    Text(value)
                        .font(input.theme.type.bodyEmphasis.monospacedDigit())
                        .foregroundStyle(input.theme.color.text)
                    if let label {
                        Text(label)
                            .font(input.theme.type.caption)
                            .foregroundStyle(input.theme.color.textSecondary)
                    }
                }
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .padding(input.height * 0.2)
            }
        }
    }
}

/// The pie legend: a swatch, the label and the value, largest first.
struct PieLegend: View {
    let input: ChartPlotInput
    let colors: [Color]

    var body: some View {
        let total = input.data.points.reduce(0) { $0 + $1.y }
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(input.data.points.enumerated()), id: \.element.id) { index, point in
                HStack(spacing: 6) {
                    Circle().fill(colors[index]).frame(width: 8, height: 8)
                    Text(point.xLabel)
                        .foregroundStyle(input.theme.color.text)
                    Spacer(minLength: 8)
                    Text(input.data.format.axisString(point.y))
                        .monospacedDigit()
                        .foregroundStyle(input.theme.color.textSecondary)
                    Text(
                        ChartValueFormat.percent.axisString(total > 0 ? point.y / total * 100 : 0)
                    )
                    .monospacedDigit()
                    .foregroundStyle(input.theme.color.textMuted)
                    .frame(minWidth: 44, alignment: .trailing)
                }
                .font(input.tokens.axisFont)
                .opacity(input.isDimmed(point.xLabel) ? 0.5 : 1)
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: 260, alignment: .leading)
    }
}

/// One value printed large (a one-slice pie; a one-cell treemap).
public struct SingleValueView: View {
    let input: ChartPlotInput
    let point: ChartPoint

    public init(input: ChartPlotInput, point: ChartPoint) {
        self.input = input
        self.point = point
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(input.data.text(point.y))
                .font(input.theme.type.display.monospacedDigit())
                .foregroundStyle(input.theme.color.text)
            Text(point.xLabel)
                .font(input.theme.type.caption)
                .foregroundStyle(input.theme.color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
