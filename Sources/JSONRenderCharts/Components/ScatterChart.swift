internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// The relation between two measures: points, bubbles sized by a field, and an optional
/// least-squares trend line.
public struct ScatterChart: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.scatter.rawValue,
        description:
            "The relation between two measures. size makes bubbles; trend adds a linear fit.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("x", "Numeric field for x."),
                ChartProps.field("y", "Numeric field for y."),
                ChartProps.field("size", "Numeric field for the bubble size.", optional: true),
                ChartProps.field("series", "Field that colours points by series.", optional: true),
                ChartProps.choice(
                    "trend", ChartOptions.Trend.allCases.map(\.rawValue), "Default none."),
                ChartProps.xDomain,
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["tests": 61, "secs": 11.2]), .object(["tests": 38, "secs": 8.6]),
            ]),
            "x": "tests", "y": "secs", "trend": "linear",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .scatter, context: context) { input in
            ScatterChartPlot(input: input)
        }
    }
}

struct ScatterChartPlot: View {
    let input: ChartPlotInput

    var body: some View {
        let data = input.data
        let xDomain = data.xDomain ?? 0...1
        Chart {
            ForEach(data.points) { point in
                PointMark(
                    x: .value(data.xField, point.x.numeric ?? 0), y: .value(data.yField, point.y)
                )
                .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                .symbolSize(symbolArea(point))
                .opacity(data.options.sizeRange == nil ? 0.9 : 0.6)
                .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
            }
            if let fit = data.options.fit {
                LineMark(
                    x: .value(data.xField, xDomain.lowerBound),
                    y: .value(data.yField, fit.y(at: xDomain.lowerBound)),
                    series: .value("Fit", "fit")
                )
                .foregroundStyle(input.theme.color.textSecondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                LineMark(
                    x: .value(data.xField, xDomain.upperBound),
                    y: .value(data.yField, fit.y(at: xDomain.upperBound)),
                    series: .value("Fit", "fit")
                )
                .foregroundStyle(input.theme.color.textSecondary)
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
            ReferenceLineMarks(input)
            SelectionRuleMark(input)
        }
        .jrMarkOverride(input)
        .jrValueAxes(input)
        .jrSeriesLegend(input)
        .chartXScale(domain: xDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(
                    input.tokens.gridline)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(ChartValueFormat.number.axisString(number)).font(input.tokens.axisFont)
                    }
                }
            }
        }
        .jrXSelection(input)
    }

    /// The point area: the token diameter, or 16…400 pt² scaled by `size`.
    private func symbolArea(_ point: ChartPoint) -> Double {
        let base = input.tokens.pointSize * input.tokens.pointSize
        guard let range = input.data.options.sizeRange, let size = point.size else { return base }
        let span = range.upperBound - range.lowerBound
        let fraction = span > 0 ? (size - range.lowerBound) / span : 0.5
        return 16 + fraction * 384
    }
}
