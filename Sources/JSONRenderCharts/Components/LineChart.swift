internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// A trend over time: one or more series, linear, monotone or stepped. Points show
/// automatically up to 30 per series. More than 1,000 points are downsampled (LTTB).
public struct LineChart: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.line.rawValue,
        description: "A trend over time. One line per series; ISO dates make a time axis.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("x", "Field for x (ISO dates make a time axis)."),
                ChartProps.field("y", "Field for the value."),
                ChartProps.field("series", "Field that splits lines into series.", optional: true),
                ChartProps.choice(
                    "curve", ChartOptions.Curve.allCases.map(\.rawValue), "Default linear."),
                ChartProps.choice(
                    "points", ChartOptions.Points.allCases.map(\.rawValue),
                    "auto shows points up to 30 per series."),
                ChartProps.xDomain,
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["run": "4210", "secs": 38]), .object(["run": "4211", "secs": 42]),
            ]),
            "x": "run", "y": "secs", "unit": "s",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .line, context: context) { input in
            LineChartPlot(input: input)
        }
    }
}

struct LineChartPlot: View {
    let input: ChartPlotInput

    private var showsPoints: Bool {
        switch input.data.options.points {
        case .always: true
        case .never: false
        case .auto:
            input.data.points.count / max(input.data.series.count, 1) <= ChartBudgets.autoPointLimit
        }
    }

    private var interpolation: InterpolationMethod {
        switch input.data.options.curve {
        case .linear: .linear
        case .monotone: .monotone
        case .step: .stepCenter
        }
    }

    var body: some View {
        let data = input.data
        let diameter = input.tokens.pointSize
        Chart {
            ForEach(data.points) { point in
                XMarks.line(point, data: data)
                    .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                    .lineStyle(input.colors.stroke(seriesIndex(point)))
                    .interpolationMethod(interpolation)
                    .accessibilityLabel(ChartAccessibilityDescriptor.label(point, data: data))
                if showsPoints {
                    XMarks.point(point, data: data)
                        .foregroundStyle(by: .value("Series", input.styleKey(for: point)))
                        .symbolSize(diameter * diameter)
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

    private func seriesIndex(_ point: ChartPoint) -> Int {
        input.data.series.firstIndex(of: point.series) ?? 0
    }
}

/// `chartXScale` for a numeric x axis with a known domain.
struct NumericXScale: ViewModifier {
    let input: ChartPlotInput

    func body(content: Content) -> some View {
        if input.data.xAxis == .number, let domain = input.data.xDomain {
            content.chartXScale(domain: domain)
        } else {
            content
        }
    }
}
