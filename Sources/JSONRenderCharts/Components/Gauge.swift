public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// One value against a range: a semicircle arc, a ring or a linear bar, with optional
/// intent bands and a target marker. The value is always printed as text, so colour is
/// never the only signal. Built on SwiftUI `Gauge` with themed `GaugeStyle`s.
///
/// The component is named `Gauge` in specs; in Swift it is `JRGauge`, so it does not hide
/// SwiftUI's `Gauge`.
public struct JRGauge: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.gauge.rawValue,
        description:
            "One value against a range: a budget, coverage, CPU. The value is always printed.",
        props: .object(
            [
                PropSchema.Field(name: "value", schema: .number, description: "The value."),
                PropSchema.Field(
                    name: "min", schema: PropSchema.number.optional(), description: "Default 0."),
                PropSchema.Field(
                    name: "max", schema: PropSchema.number.optional(), description: "Default 100."),
                ChartProps.field("label", "What the value is.", optional: true),
                PropSchema.Field(
                    name: "target", schema: PropSchema.number.optional(),
                    description: "A marker on the scale."),
                PropSchema.Field(
                    name: "bands",
                    schema: PropSchema.array(
                        .object([
                            .init(name: "to", schema: .number),
                            .init(name: "intent", schema: .enum(ChartIntent.acceptedNames)),
                        ])
                    ).optional(),
                    description: "Colour bands up to a value: good | warn | risk | info."),
                ChartProps.choice(
                    "style", GaugeModel.Style.allCases.map(\.rawValue), "Default arc."),
                ChartProps.format, ChartProps.unit, ChartProps.summary, ChartProps.variant,
                ChartProps.title, ChartProps.caption,
            ]),
        slots: ["title", "caption", "center"],
        example: ["value": 3.6, "max": 5, "format": "currency:USD", "label": "Voice budget"])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        let model = GaugeModel.make(props: context.props)
        ChartContainer(
            kind: .gauge, context: context, make: JRGauge.makeData, fixedHeight: false,
            summary: model.summary()
        ) { input in
            GaugeView(model: model, input: input)
        }
    }

    /// Decodes props into chart data (the container's `make`).
    @Sendable nonisolated static func makeData(_ props: [String: JSONValue?])
        -> (ChartData, [ChartWarning])
    {
        data(GaugeModel.make(props: props))
    }

    /// The gauge as chart data (for the descriptor and "Show as Table").
    nonisolated static func data(_ model: GaugeModel) -> (ChartData, [ChartWarning]) {
        let label = model.label ?? "value"
        var data = ChartData(
            kind: .gauge,
            points: [ChartPoint(id: 0, x: .category(label), xLabel: label, y: model.value)],
            categories: [label], xField: "label", yField: label, format: model.format,
            unit: model.unit, dataRange: model.min...model.max, yDomain: model.min...model.max,
            yDomainIsFixed: true)
        if let target = model.target {
            data.referenceLines = [ChartReferenceLine(value: target, label: "Target")]
        }
        return (data, [])
    }
}

struct GaugeView: View {
    let model: GaugeModel
    let input: ChartPlotInput

    var body: some View {
        let gauge = SwiftUI.Gauge(value: model.fraction) {
            Text(model.label ?? "")
        } currentValueLabel: {
            Text(model.valueText())
        }
        switch model.style {
        case .arc:
            gauge.gaugeStyle(BandedGaugeStyle(model: model, input: input, shape: .arc))
        case .ring:
            gauge.gaugeStyle(BandedGaugeStyle(model: model, input: input, shape: .ring))
        case .linear:
            gauge.gaugeStyle(LinearBandedGaugeStyle(model: model, input: input))
        }
    }
}

/// The colour of the value: the band it falls in, else the accent.
private func valueColor(_ model: GaugeModel, _ input: ChartPlotInput) -> Color {
    model.currentIntent.map(input.colors.intent) ?? input.colors.single
}

/// Arc (a 240° sweep) and ring (360°) gauges with bands and a target tick.
struct BandedGaugeStyle: GaugeStyle {
    enum Shape { case arc, ring }

    let model: GaugeModel
    let input: ChartPlotInput
    let shape: Shape

    private var sweep: Double { shape == .arc ? 240 : 360 }
    private var start: Double { shape == .arc ? 150 : -90 }

    func makeBody(configuration: Configuration) -> some View {
        let width = input.tokens.gaugeTrackWidth
        let size = min(max(input.height, 96), 160)
        VStack(alignment: .center, spacing: 2) {
            ZStack {
                ArcShape(start: start, sweep: sweep, from: 0, to: 1)
                    .stroke(
                        input.theme.color.hairline,
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                ForEach(Array(bandSpans.enumerated()), id: \.offset) { _, span in
                    ArcShape(start: start, sweep: sweep, from: span.from, to: span.to)
                        .stroke(
                            input.colors.intent(span.intent).opacity(0.28),
                            style: StrokeStyle(lineWidth: width, lineCap: .butt))
                }
                ArcShape(start: start, sweep: sweep, from: 0, to: configuration.value)
                    .stroke(
                        valueColor(model, input),
                        style: StrokeStyle(lineWidth: width, lineCap: .round))
                if let target = model.targetFraction {
                    TargetTick(start: start, sweep: sweep, at: target, length: width * 1.8)
                        .stroke(
                            input.theme.color.text,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                VStack(spacing: 0) {
                    if let slot = input.center, !slot.isEmpty {
                        slot
                    } else {
                        configuration.currentValueLabel
                            .font(input.theme.type.title.monospacedDigit())
                            .foregroundStyle(input.theme.color.text)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text(model.rangeText())
                            .font(input.theme.type.caption.monospacedDigit())
                            .foregroundStyle(input.theme.color.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                }
                .padding(width * 2)
                .offset(y: shape == .arc ? size * 0.04 : 0)
            }
            .frame(width: size, height: shape == .arc ? size * 0.82 : size)
            configuration.label
                .font(input.theme.type.footnote)
                .foregroundStyle(input.theme.color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// The band spans as fractions of the scale.
    private var bandSpans: [(from: Double, to: Double, intent: ChartIntent)] {
        var lower = 0.0
        var spans: [(Double, Double, ChartIntent)] = []
        for band in model.bands {
            let upper = min(max((band.upTo - model.min) / (model.max - model.min), 0), 1)
            if upper > lower { spans.append((lower, upper, band.intent)) }
            lower = max(lower, upper)
        }
        return spans
    }
}

/// A linear capacity bar with bands, a target marker and the value printed beside it.
struct LinearBandedGaugeStyle: GaugeStyle {
    let model: GaugeModel
    let input: ChartPlotInput

    func makeBody(configuration: Configuration) -> some View {
        let width = input.tokens.gaugeTrackWidth
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                configuration.label
                    .font(input.theme.type.footnote)
                    .foregroundStyle(input.theme.color.textSecondary)
                Spacer()
                configuration.currentValueLabel
                    .font(input.theme.type.bodyEmphasis.monospacedDigit())
                    .foregroundStyle(input.theme.color.text)
            }
            GeometryReader { proxy in
                let total = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(input.theme.color.hairline)
                    ForEach(Array(model.bands.enumerated()), id: \.offset) { index, band in
                        let lower =
                            index == 0
                            ? 0
                            : (model.bands[index - 1].upTo - model.min) / (model.max - model.min)
                        let upper = (band.upTo - model.min) / (model.max - model.min)
                        Rectangle()
                            .fill(input.colors.intent(band.intent).opacity(0.28))
                            .frame(width: max(0, min(upper, 1) - max(lower, 0)) * total)
                            .offset(x: max(lower, 0) * total)
                    }
                    Capsule()
                        .fill(valueColor(model, input))
                        .frame(width: max(width, configuration.value * total))
                    if let target = model.targetFraction {
                        Rectangle()
                            .fill(input.theme.color.text)
                            .frame(width: 2, height: width * 1.8)
                            .offset(x: target * total - 1)
                    }
                }
                .clipShape(Capsule())
                .frame(height: width)
                .frame(maxHeight: .infinity)
            }
            .frame(height: width * 1.8)
            HStack {
                Text(model.rangeText())
                if let target = model.target {
                    Spacer()
                    Text("target \(model.format.string(target, unit: model.unit))")
                }
            }
            .font(input.theme.type.caption.monospacedDigit())
            .foregroundStyle(input.theme.color.textSecondary)
        }
    }
}

/// An arc from `from` to `to` (fractions of `sweep`, starting at `start` degrees).
struct ArcShape: SwiftUI.Shape {
    let start: Double
    let sweep: Double
    let from: Double
    let to: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height / (sweep < 360 ? 0.82 : 1)) / 2 - 8
        let center = CGPoint(x: rect.midX, y: sweep < 360 ? radius + 8 : rect.midY)
        var path = Path()
        path.addArc(
            center: center, radius: max(radius, 1),
            startAngle: .degrees(start + sweep * from), endAngle: .degrees(start + sweep * to),
            clockwise: false)
        return path
    }
}

/// A radial tick across the track at a fraction of the sweep.
struct TargetTick: SwiftUI.Shape {
    let start: Double
    let sweep: Double
    let at: Double
    let length: Double

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height / (sweep < 360 ? 0.82 : 1)) / 2 - 8
        let center = CGPoint(x: rect.midX, y: sweep < 360 ? radius + 8 : rect.midY)
        let angle = (start + sweep * at) * .pi / 180
        let inner = radius - length / 2
        let outer = radius + length / 2
        var path = Path()
        path.move(to: CGPoint(x: center.x + inner * cos(angle), y: center.y + inner * sin(angle)))
        path.addLine(
            to: CGPoint(x: center.x + outer * cos(angle), y: center.y + outer * sin(angle)))
        return path
    }
}
