internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Values and their average: bars and a line on one y axis. Never two y axes; the
/// validator rejects a second unit.
public struct ComboChart: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.combo.rawValue,
        description:
            "Bars and a line (such as a moving average) on one y axis. Never two axes: the validator rejects a second unit.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("x", "Field for the category."),
                ChartProps.field("bars", "Field drawn as bars."),
                ChartProps.field("line", "Field drawn as a line, in the same unit."),
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["day": "Mon", "secs": 41, "avg": 40]),
                .object(["day": "Tue", "secs": 38, "avg": 40]),
            ]),
            "x": "day", "bars": "secs", "line": "avg", "unit": "s",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .combo, context: context) { input in
            ComboChartPlot(input: input)
        }
    }
}

struct ComboChartPlot: View {
    let input: ChartPlotInput

    var body: some View {
        let data = input.data
        let lineField = data.options.lineField ?? "line"
        let diameter = input.tokens.pointSize
        Chart {
            ForEach(data.points.filter { $0.series == data.yField }) { point in
                BarMark(x: .value(data.xField, point.xLabel), y: .value("Value", point.y))
                    .foregroundStyle(by: .value("Series", point.series))
                    .cornerRadius(input.tokens.barCornerRadius)
                    .opacity(input.isDimmed(point.xLabel) ? 0.35 : 0.85)
                    .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
            }
            ForEach(data.points.filter { $0.series == lineField }) { point in
                LineMark(
                    x: .value(data.xField, point.xLabel), y: .value("Value", point.y),
                    series: .value("Series", point.series)
                )
                .foregroundStyle(by: .value("Series", point.series))
                .lineStyle(StrokeStyle(lineWidth: input.tokens.lineWidth, lineCap: .round))
                .interpolationMethod(.monotone)
                .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
                PointMark(x: .value(data.xField, point.xLabel), y: .value("Value", point.y))
                    .foregroundStyle(by: .value("Series", point.series))
                    .symbolSize(diameter * diameter)
                    .accessibilityHidden(true)
            }
            ReferenceLineMarks(input)
            SelectionRuleMark(input)
        }
        .jrMarkOverride(input)
        .jrValueAxes(input)
        .jrSeriesLegend(input)
        .jrPointerSelection(input, axis: .x)
    }
}
