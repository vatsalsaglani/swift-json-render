internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Compare categories: vertical or horizontal; grouped, stacked or 100 % stacked; ranked
/// with `sort` and `limit` (the rest folds into a grey "Other" bar). Bars start at zero.
///
/// The reference implementation for every chart: a `nonisolated` definition built from
/// `ChartProps`, and a body that is one `ChartContainer` with the marks.
public struct BarChart: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.bar.rawValue,
        description:
            "Compare categories. Horizontal when labels are long; stacked or normalized (100 %) for parts of each bar.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("x", "Field for the category."),
                ChartProps.field("y", "Field for the value."),
                ChartProps.field("series", "Field that splits bars into series.", optional: true),
                ChartProps.choice(
                    "orientation", ChartOptions.Orientation.allCases.map(\.rawValue),
                    "Default vertical."),
                ChartProps.choice(
                    "layout", ChartOptions.BarLayout.allCases.map(\.rawValue), "Default grouped."),
                ChartProps.choice(
                    "sort", ChartOptions.Sort.allCases.map(\.rawValue),
                    "Sort by bar total. Default none."),
                PropSchema.Field(
                    name: "limit", schema: PropSchema.number.optional(),
                    description: "Keep the first N bars; the rest fold into \"Other\"."),
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["run": "4208", "n": 1210]), .object(["run": "4209", "n": 1225]),
            ]),
            "x": "run", "y": "n",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .bar, context: context) { input in
            BarChartPlot(input: input)
        }
    }
}

/// The default bar plot.
struct BarChartPlot: View {
    let input: ChartPlotInput

    private var horizontal: Bool { input.data.options.orientation == .horizontal }
    private var grouped: Bool {
        input.data.options.barLayout == .grouped && input.data.hasSeries
    }

    var body: some View {
        Chart {
            ForEach(input.data.points) { point in
                if grouped {
                    mark(point)
                        .position(by: .value("Series", point.series))
                        .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                        .cornerRadius(input.tokens.barCornerRadius)
                        .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                        .accessibilityLabel(label(point))
                } else {
                    mark(point)
                        .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                        .cornerRadius(point.base == nil ? input.tokens.barCornerRadius : 0)
                        .opacity(input.isDimmed(point.xLabel) ? 0.35 : 1)
                        .accessibilityLabel(label(point))
                        .annotation(position: horizontal ? .trailing : .top, spacing: 4) {
                            if horizontal, !input.data.hasSeries {
                                Text(input.data.format.axisString(point.y))
                                    .font(input.tokens.axisFont)
                                    .foregroundStyle(input.theme.color.textSecondary)
                            }
                        }
                }
            }
            ReferenceLineMarks(input, horizontal: horizontal)
            if let selected = input.selection.wrappedValue, !horizontal,
                input.data.categories.contains(selected)
            {
                RuleMark(x: .value(input.data.xField, selected))
                    .foregroundStyle(.clear)
                    .annotation(
                        position: .top, spacing: 0,
                        overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                    ) {
                        ChartTooltip(input, label: selected)
                    }
            }
        }
        .jrMarkOverride(input)
        .jrValueAxes(input, horizontal: horizontal)
        .jrSeriesLegend(input)
        .jrPointerSelection(input, axis: horizontal ? .y : .x)
    }

    /// One bar. Stacked bars span `base...base + y`, inset by a 1 pt gap in data units so
    /// segments are separated by the card colour.
    private func mark(_ point: ChartPoint) -> BarMark {
        let x = PlottableValue.value(input.data.xField, point.xLabel)
        if let base = point.base {
            let gap = gapUnits / 2
            let start = base + (point.y >= 0 ? gap : -gap)
            var end = base + point.y
            end -= point.y >= 0 ? gap : -gap
            let (low, high) = abs(point.y) > gapUnits * 2 ? (start, end) : (base, base + point.y)
            if horizontal {
                return BarMark(
                    xStart: .value(input.data.yField, low), xEnd: .value(input.data.yField, high),
                    y: x)
            }
            return BarMark(
                x: x, yStart: .value(input.data.yField, low), yEnd: .value(input.data.yField, high))
        }
        let y = PlottableValue.value(input.data.yField, point.y)
        return horizontal ? BarMark(x: y, y: x) : BarMark(x: x, y: y)
    }

    /// One point of plot height in data units (approximate: the plot is a little shorter
    /// than the frame because of the axis labels).
    private var gapUnits: Double {
        let span = input.yDomain.upperBound - input.yDomain.lowerBound
        return span / max(input.height, 1)
    }

    private func label(_ point: ChartPoint) -> String {
        ChartAccessibilityDescriptor.label(point, data: input.data)
    }
}
