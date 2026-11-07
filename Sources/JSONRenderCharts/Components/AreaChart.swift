internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Totals and their parts over time: overlapping areas, stacked areas (the top edge is the
/// total) or 100 % shares.
public struct AreaChart: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.area.rawValue,
        description:
            "Totals and their parts over time. stacked: the top edge is the total; normalized: 100 % shares.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("x", "Field for x (ISO dates make a time axis)."),
                ChartProps.field("y", "Field for the value."),
                ChartProps.field("series", "Field that splits areas into series.", optional: true),
                ChartProps.choice(
                    "layout", ChartOptions.AreaLayout.allCases.map(\.rawValue), "Default overlap."),
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["day": "Mon", "agent": "Claude", "k": 30]),
                .object(["day": "Mon", "agent": "Codex", "k": 12]),
            ]),
            "x": "day", "y": "k", "series": "agent", "layout": "stacked",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .area, context: context) { input in
            AreaChartPlot(input: input)
        }
    }
}

struct AreaChartPlot: View {
    let input: ChartPlotInput

    private var overlap: Bool { input.data.options.areaLayout == .overlap }

    var body: some View {
        let data = input.data
        let stacking: MarkStackingMethod = overlap ? .unstacked : .standard
        Chart {
            ForEach(data.points) { point in
                XMarks.area(point, data: data, stacking: stacking)
                    .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                    .opacity(overlap ? 0.3 : 0.85)
                    .interpolationMethod(.linear)
                    .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
                if overlap {
                    XMarks.line(point, data: data)
                        .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                        .lineStyle(StrokeStyle(lineWidth: input.tokens.lineWidth))
                        .accessibilityHidden(true)
                }
            }
            ReferenceLineMarks(input)
            SelectionRuleMark(input)
        }
        .jrMarkOverride(input)
        .jrValueAxes(input)
        .jrSeriesLegend(input)
        .modifier(NumericXScale(input: input))
        .jrXSelection(input)
    }
}
