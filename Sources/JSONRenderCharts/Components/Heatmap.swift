internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Activity by day and hour, or failures by suite and run: one hue that darkens with the
/// value (sequential), or a diverging ramp when the data crosses a meaningful midpoint.
/// `layout: calendar` with ISO dates draws weeks × weekdays.
public struct Heatmap: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.heatmap.rawValue,
        description:
            "A grid of values: activity by day and hour, failures by suite and run. calendar draws weeks by weekdays from ISO dates.",
        props: .object([
            ChartProps.data,
            ChartProps.field("x", "Field for the column."),
            ChartProps.field("y", "Field for the row."),
            ChartProps.field("value", "Numeric field for the cell."),
            ChartProps.choice(
                "scale", ChartOptions.HeatScale.allCases.map(\.rawValue),
                "Default sequential; diverging only around a meaningful midpoint."),
            ChartProps.choice(
                "layout", ChartOptions.HeatLayout.allCases.map(\.rawValue), "Default grid."),
            ChartProps.format, ChartProps.unit, ChartProps.legend, ChartProps.height,
            ChartProps.selection, ChartProps.emptyText, ChartProps.summary, ChartProps.variant,
            ChartProps.title, ChartProps.caption,
        ]),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["hour": "08:00", "day": "Mon", "n": 3]),
                .object(["hour": "09:00", "day": "Mon", "n": 7]),
            ]),
            "x": "hour", "y": "day", "value": "n",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .heatmap, context: context) { input in
            HeatmapPlot(input: input)
        }
    }
}

struct HeatmapPlot: View {
    let input: ChartPlotInput

    var body: some View {
        let data = input.data
        VStack(alignment: .leading, spacing: 4) {
            Chart {
                ForEach(data.points) { point in
                    RectangleMark(
                        x: .value(data.xField, point.x.categoryLabel),
                        y: .value(data.yField, point.row ?? ""),
                        width: .ratio(0.92), height: .ratio(0.88)
                    )
                    .foregroundStyle(color(point.y))
                    .cornerRadius(2)
                    .opacity(input.isDimmed(point.x.categoryLabel) ? 0.4 : 1)
                    .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
                }
            }
            .jrMarkOverride(input)
            .chartXScale(domain: data.categories)
            .chartYScale(domain: data.rows)
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(collisionResolution: .greedy(minimumSpacing: 6))
                        .font(input.tokens.axisFont)
                }
            }
            .chartYAxis {
                // `.aligned` puts row labels beside the rows. The macOS default for a
                // categorical y axis draws them inside each band, which squeezes short rows.
                AxisMarks(preset: .aligned, position: .leading) { _ in
                    AxisValueLabel().font(input.tokens.axisFont)
                }
            }
            .chartXAxis(input.hidesAxes ? .hidden : .automatic)
            .chartYAxis(input.hidesAxes ? .hidden : .automatic)
            .chartLegend(.hidden)
            .jrPointerSelection(input, axis: .x)
            if input.legend != .hidden, let range = data.options.valueRange {
                HeatmapLegend(input: input, range: range, color: color)
            }
        }
    }

    /// The cell colour for `value`.
    private func color(_ value: Double) -> Color {
        guard let range = input.data.options.valueRange else { return input.colors.sequential(1) }
        switch input.data.options.heatScale {
        case .sequential:
            let span = range.upperBound - range.lowerBound
            return input.colors.sequential(span > 0 ? (value - range.lowerBound) / span : 1)
        case .diverging:
            let mid =
                range.lowerBound < 0 && range.upperBound > 0
                ? 0 : (range.lowerBound + range.upperBound) / 2
            let reach = max(range.upperBound - mid, mid - range.lowerBound, 1e-9)
            return input.colors.diverging(0.5 + (value - mid) / reach / 2)
        }
    }
}

/// A small ramp with the low and high values.
struct HeatmapLegend: View {
    let input: ChartPlotInput
    let range: ClosedRange<Double>
    let color: (Double) -> Color

    var body: some View {
        HStack(spacing: 6) {
            Text(input.data.text(range.lowerBound))
            HStack(spacing: 1) {
                ForEach(0..<5, id: \.self) { step in
                    Rectangle()
                        .fill(
                            color(
                                range.lowerBound + (range.upperBound - range.lowerBound)
                                    * Double(step) / 4)
                        )
                        .frame(width: 14, height: 8)
                }
            }
            Text(input.data.text(range.upperBound))
        }
        .font(input.tokens.axisFont.monospacedDigit())
        .foregroundStyle(input.theme.color.textSecondary)
        .accessibilityHidden(true)
    }
}

extension ChartXValue {
    /// The category text (heatmap columns are always categories).
    var categoryLabel: String {
        switch self {
        case .category(let text): text
        case .date(let date): date.formatted(date: .abbreviated, time: .omitted)
        case .number(let value): ChartValueFormat.number.axisString(value)
        }
    }
}
