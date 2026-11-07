internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// A distribution, such as test durations: equal-width bins (Freedman–Diaconis for
/// `bins: "auto"`), counts or percentages, one hue, bars from zero.
public struct Histogram: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.histogram.rawValue,
        description: "A distribution, such as test durations. bins: \"auto\" or a count.",
        props: .object([
            PropSchema.Field(
                name: "values", schema: .array(.number),
                description: "Numbers, or { \"$state\": \"/durations\" }."),
            PropSchema.Field(
                name: "bins", schema: PropSchema.union([.number, .literal("auto")]).optional(),
                description: "auto (Freedman–Diaconis) or a count up to 100."),
            ChartProps.choice(
                "mode", ChartOptions.HistogramMode.allCases.map(\.rawValue), "Default count."),
            ChartProps.format, ChartProps.unit, ChartProps.height, ChartProps.selection,
            ChartProps.emptyText, ChartProps.summary, ChartProps.variant, ChartProps.title,
            ChartProps.caption,
        ]),
        slots: ChartProps.slots,
        example: ["values": .array([2.7, 1.4, 2.5, 1.7, 3.1, 5.8]), "bins": "auto", "unit": "s"])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .histogram, context: context) { input in
            HistogramPlot(input: input)
        }
    }
}

struct HistogramPlot: View {
    let input: ChartPlotInput

    var body: some View {
        let data = input.data
        let xFormat = data.options.xFormat
        Chart {
            ForEach(data.points) { point in
                let lower = point.x.numeric ?? 0
                let upper = point.xEnd ?? lower
                let inset = (upper - lower) * 0.04
                RectangleMark(
                    xStart: .value(data.xField, lower + inset),
                    xEnd: .value(data.xField, upper - inset),
                    yStart: .value(data.yField, 0),
                    yEnd: .value(data.yField, point.y)
                )
                .cornerRadius(input.tokens.barCornerRadius)
                .foregroundStyle(input.colors.single)
                .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
            }
            SelectionRuleMark(input)
        }
        .jrMarkOverride(input)
        .jrValueAxes(input)
        .chartLegend(.hidden)
        .chartXScale(domain: data.xDomain ?? 0...1)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                AxisTick()
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(xFormat.string(number, unit: data.options.xUnit))
                            .font(input.tokens.axisFont)
                    }
                }
            }
        }
        .jrXSelection(input)
    }
}
