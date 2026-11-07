internal import Charts
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// A tiny trend with no axes, for a Stat or a Table cell. A dot marks the last (or the
/// highest) value. `intent` colours it only for a status.
public struct Sparkline: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.sparkline.rawValue,
        description: "A tiny trend inside a Stat or a Table cell. No axes.",
        props: .object([
            PropSchema.Field(
                name: "values", schema: .array(.number),
                description: "Numbers in order, or { \"$state\": \"/series\" }."),
            ChartProps.choice(
                "intent", ["good", "warn", "risk", "info"], "Colours the line only for a status."),
            ChartProps.choice(
                "emphasis", ChartOptions.Emphasis.allCases.map(\.rawValue),
                "Which point gets a dot. Default last."),
            PropSchema.Field(
                name: "filled", schema: PropSchema.boolean.optional(),
                description: "Fill under the line."),
            ChartProps.format, ChartProps.height, ChartProps.summary, ChartProps.title,
            ChartProps.caption,
        ]),
        slots: ["title", "caption"],
        example: ["values": .array([8, 10, 6, 14, 12, 16, 18, 20, 22]), "emphasis": "last"])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .sparkline, context: context, fixedHeight: false) { input in
            SparklinePlot(input: input)
        }
    }
}

struct SparklinePlot: View {
    let input: ChartPlotInput

    private var color: Color {
        input.data.options.intent.map(input.colors.intent) ?? input.colors.single
    }

    private var emphasized: ChartPoint? {
        switch input.data.options.emphasis {
        case .last: input.data.points.last
        case .max: input.data.points.max { $0.y < $1.y }
        case .none: nil
        }
    }

    var body: some View {
        let data = input.data
        let explicitHeight = (input.props["height"] ?? nil) != nil
        let low = data.dataRange?.lowerBound ?? 0
        let high = data.dataRange?.upperBound ?? 1
        let pad = max((high - low) * 0.12, 1e-9)
        Chart {
            ForEach(data.points) { point in
                if data.options.filled {
                    AreaMark(
                        x: .value("Point", point.x.numeric ?? 0),
                        yStart: .value("Value", low - pad),
                        yEnd: .value("Value", point.y)
                    )
                    .foregroundStyle(color.opacity(0.18))
                    .interpolationMethod(.monotone)
                }
                LineMark(x: .value("Point", point.x.numeric ?? 0), y: .value("Value", point.y))
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: input.tokens.lineWidth, lineCap: .round))
                    .interpolationMethod(.monotone)
            }
            if let emphasized {
                PointMark(
                    x: .value("Point", emphasized.x.numeric ?? 0), y: .value("Value", emphasized.y)
                )
                .foregroundStyle(color)
                .symbolSize(input.tokens.pointSize * input.tokens.pointSize * 1.4)
            }
        }
        .jrMarkOverride(input)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartYScale(domain: (low - pad)...(high + pad))
        .chartXScale(domain: data.xDomain ?? 0...1)
        .frame(height: explicitHeight ? input.height : 32)
        .frame(minWidth: 48)
    }
}
