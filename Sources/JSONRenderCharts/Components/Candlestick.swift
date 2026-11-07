internal import Charts
internal import Foundation
public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

/// Open, high, low and close per period. An up period (close ≥ open) has a filled body in
/// the good hue; a down period has a hollow body in the critical hue, so colour is never
/// the only signal. A legend under the plot says which is which. `mark: ohlc` draws OHLC
/// bars (open tick left, close tick right). More than 180 periods keep the last 180.
public struct Candlestick: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.candlestick.rawValue,
        description:
            "Open, high, low and close per period: cost per day, build time min and max per day. Up periods are filled, down periods hollow. At most 180 periods (the last ones).",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("x", "Field for the period (a label or an ISO date)."),
                ChartProps.field(
                    "open", "Field for the open value. Default \"open\".", optional: true),
                ChartProps.field(
                    "high", "Field for the high value. Default \"high\".", optional: true),
                ChartProps.field(
                    "low", "Field for the low value. Default \"low\".", optional: true),
                ChartProps.field(
                    "close", "Field for the close value. Default \"close\".", optional: true),
                ChartProps.choice(
                    "mark", CandlestickOptions.Mark.allCases.map(\.rawValue),
                    "candles (default) or ohlc bars."),
                ChartProps.choice(
                    "style", CandlestickOptions.Mark.allCases.map(\.rawValue),
                    "Another name for mark."),
            ] + ChartProps.chrome()),
        slots: ChartProps.slots,
        example: [
            "data": .array([
                .object(["day": "D1", "open": 10, "high": 12, "low": 9, "close": 11]),
                .object(["day": "D2", "open": 11, "high": 13, "low": 10, "close": 10.5]),
            ]),
            "x": "day", "format": "currency:USD",
        ])

    let context: JRRenderContext

    public init(context: JRRenderContext) {
        self.context = context
    }

    public var body: some View {
        ChartContainer(kind: .candlestick, context: context, make: CandlestickData.make) { input in
            CandlestickPlot(input: input)
        }
    }
}

public enum CandlestickOptions {
    public enum Mark: String, Sendable, CaseIterable { case candles, ohlc }
}

/// One period.
public struct CandlePeriod: Sendable, Hashable {
    public var label: String
    public var open: Double
    public var high: Double
    public var low: Double
    public var close: Double

    /// `true` when the period closes at or above its open.
    public var isUp: Bool { close >= open }
    /// `true` when the body is drawn hollow (the period closes down).
    public var isHollow: Bool { !isUp }
    public var bodyLow: Double { min(open, close) }
    public var bodyHigh: Double { max(open, close) }
}

/// Candlestick data. Each period becomes four points (rows `open`, `high`, `low`, `close`),
/// so "Show as Table" and VoiceOver read every number.
public enum CandlestickData {
    static let rowNames = ["open", "high", "low", "close"]

    public static func make(props: [String: JSONValue?]) -> (ChartData, [ChartWarning]) {
        let reader = ChartPropReader(props)
        var warnings: [ChartWarning] = []
        var data = CompositeData.start(kind: .candlestick, reader: reader, warnings: &warnings)
        let xField = reader.string("x") ?? "x"
        let fields = rowNames.map { reader.string($0) ?? $0 }
        data.xField = xField
        data.yField = reader.string("unit") ?? "value"
        var skipped = 0
        var periods: [(label: String, date: Date?, values: [Double])] = []
        for row in CompositeData.objects(reader, skipped: &skipped) {
            let values = fields.compactMap { ChartValues.number(row[$0]) }
            guard let label = ChartValues.text(row[xField]), values.count == 4 else {
                skipped += 1
                continue
            }
            periods.append((label, ChartDates.parse(label), values))
        }
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        let isTime = !periods.isEmpty && periods.allSatisfy { $0.date != nil }
        if isTime {
            periods = periods.enumerated().sorted { lhs, rhs in
                let left = lhs.element.date ?? .distantPast
                let right = rhs.element.date ?? .distantPast
                return left != right ? left < right : lhs.offset < rhs.offset
            }.map(\.element)
        } else if periods.contains(where: { $0.date != nil }) {
            warnings.append(.mixedTimeAxis)
        }
        let limit = CompositeBudgets.maxCandlestickPeriods
        if periods.count > limit {
            warnings.append(.downsampled(from: periods.count, to: limit))
            periods = Array(periods.suffix(limit))
        }
        data.xAxis = isTime ? .time : .category
        let labels = CompositeData.unique(periods.map(\.label))
        var points: [ChartPoint] = []
        for (index, period) in periods.enumerated() {
            let label = labels[index]
            let x: ChartXValue = period.date.map(ChartXValue.date) ?? .category(label)
            // Tolerant: low and high widen to hold open and close (the validator reports it).
            let open = period.values[0]
            let close = period.values[3]
            let high = max(period.values[1], open, close)
            let low = min(period.values[2], open, close)
            for (row, value) in zip(rowNames, [open, high, low, close]) {
                points.append(
                    ChartPoint(id: points.count, x: x, xLabel: label, y: value, row: row))
            }
        }
        data.points = points
        data.categories = labels
        data.rows = points.isEmpty ? [] : rowNames
        CompositeData.finish(
            &data, range: CompositeData.extent(points.map(\.y)), reader: reader,
            includeZero: false)
        return (data, warnings)
    }

    /// The periods of drawn data, back from the points.
    public static func periods(in data: ChartData) -> [CandlePeriod] {
        var result: [CandlePeriod] = []
        var index = 0
        let points = data.points
        while index + 3 < points.count {
            let slice = points[index..<(index + 4)]
            let values = Dictionary(
                slice.compactMap { point in point.row.map { ($0, point.y) } },
                uniquingKeysWith: { first, _ in first })
            if let open = values["open"], let high = values["high"], let low = values["low"],
                let close = values["close"]
            {
                result.append(
                    CandlePeriod(
                        label: points[index].xLabel, open: open, high: high, low: low, close: close)
                )
            }
            index += 4
        }
        return result
    }
}

/// Pointer selection on the index axis: hover highlights the period under the pointer
/// (local), a click commits it (a second click deselects). `jrPointerSelection` reads a
/// category or date from the x scale, which this index axis does not have.
struct CandlestickPointer: View {
    let input: ChartPlotInput
    let periods: [CandlePeriod]
    let proxy: ChartProxy

    var body: some View {
        GeometryReader { geometry in
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        input.selection.wrappedValue = label(at: location, geometry: geometry)
                    case .ended:
                        input.selection.wrappedValue = nil
                    }
                }
                .onTapGesture { location in
                    input.commit(label(at: location, geometry: geometry))
                }
        }
    }

    private func label(at location: CGPoint, geometry: GeometryProxy) -> String? {
        guard let anchor = proxy.plotFrame else { return nil }
        let frame = geometry[anchor]
        guard frame.contains(location),
            let value = proxy.value(atX: location.x - frame.minX, as: Double.self)
        else { return nil }
        let index = Int(value.rounded())
        return periods.indices.contains(index) ? periods[index].label : nil
    }
}

/// The default candlestick plot. Periods sit on an index axis (0, 1, 2 …) labelled with the
/// period names, so a hollow body can be drawn as four hairlines around a fixed width.
struct CandlestickPlot: View {
    let input: ChartPlotInput

    private static let halfWidth = 0.32

    var body: some View {
        let periods = CandlestickData.periods(in: input.data)
        VStack(alignment: .leading, spacing: 4) {
            chart(periods)
            if input.legend != .hidden {
                CompositeLegend(
                    entries: [
                        .init(label: "Up (close ≥ open)", color: input.colors.roles.good),
                        .init(
                            label: "Down (hollow)", color: input.colors.roles.critical,
                            filled: false),
                    ], input: input)
            }
        }
    }

    private var mark: CandlestickOptions.Mark {
        let reader = ChartPropReader(input.props)
        return reader.string("mark").flatMap(CandlestickOptions.Mark.init(rawValue:))
            ?? reader.choice("style", default: .candles)
    }

    private func chart(_ periods: [CandlePeriod]) -> some View {
        let ohlc = mark == .ohlc
        let tokens = input.tokens
        let format = input.data.axisFormat
        let ticks = tickIndices(count: periods.count)
        return Chart {
            ForEach(Array(periods.enumerated()), id: \.offset) { index, period in
                let x = Double(index)
                let color = period.isUp ? input.colors.roles.good : input.colors.roles.critical
                let dimmed = input.isDimmed(period.label) ? 0.35 : 1
                if ohlc {
                    rule(x: x, from: period.low, to: period.high)
                        .foregroundStyle(color).opacity(dimmed)
                        .accessibilityLabel(label(period))
                    rule(from: x - Self.halfWidth, to: x, y: period.open)
                        .foregroundStyle(color).opacity(dimmed)
                    rule(from: x, to: x + Self.halfWidth, y: period.close)
                        .foregroundStyle(color).opacity(dimmed)
                } else {
                    // Two wick pieces, so a hollow body stays empty.
                    rule(x: x, from: period.low, to: period.bodyLow)
                        .foregroundStyle(color).opacity(dimmed)
                    rule(x: x, from: period.bodyHigh, to: period.high)
                        .foregroundStyle(color).opacity(dimmed)
                    if period.isHollow {
                        rule(x: x - Self.halfWidth, from: period.bodyLow, to: period.bodyHigh)
                            .foregroundStyle(color).opacity(dimmed)
                            .accessibilityLabel(label(period))
                        rule(x: x + Self.halfWidth, from: period.bodyLow, to: period.bodyHigh)
                            .foregroundStyle(color).opacity(dimmed)
                        rule(
                            from: x - Self.halfWidth, to: x + Self.halfWidth, y: period.bodyLow
                        )
                        .foregroundStyle(color).opacity(dimmed)
                        rule(
                            from: x - Self.halfWidth, to: x + Self.halfWidth, y: period.bodyHigh
                        )
                        .foregroundStyle(color).opacity(dimmed)
                    } else if period.bodyHigh > period.bodyLow {
                        RectangleMark(
                            xStart: .value("Period", x - Self.halfWidth),
                            xEnd: .value("Period", x + Self.halfWidth),
                            yStart: .value(input.data.yField, period.bodyLow),
                            yEnd: .value(input.data.yField, period.bodyHigh)
                        )
                        .foregroundStyle(color).opacity(dimmed)
                        .accessibilityLabel(label(period))
                    } else {
                        // Open equals close: a flat body.
                        rule(
                            from: x - Self.halfWidth, to: x + Self.halfWidth, y: period.open
                        )
                        .foregroundStyle(color).opacity(dimmed)
                        .accessibilityLabel(label(period))
                    }
                }
            }
            ReferenceLineMarks(input)
        }
        .jrMarkOverride(input)
        .chartXScale(domain: -0.6...(Double(max(periods.count, 1)) - 0.4))
        .chartYScale(domain: input.yDomain)
        .chartXAxis {
            AxisMarks(values: ticks) { value in
                AxisValueLabel {
                    if let index = value.as(Double.self) {
                        Text(tickLabel(Int(index.rounded()), periods: periods))
                            .font(tokens.axisFont)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5)).foregroundStyle(tokens.gridline)
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(format.axisString(number)).font(tokens.axisFont)
                    }
                }
            }
        }
        .chartXAxis(input.hidesAxes ? .hidden : .automatic)
        .chartYAxis(input.hidesAxes ? .hidden : .automatic)
        .chartLegend(.hidden)
        .chartOverlay { proxy in
            CandlestickPointer(input: input, periods: periods, proxy: proxy)
        }
    }

    private func rule(x: Double, from low: Double, to high: Double) -> RuleMark {
        RuleMark(
            x: .value("Period", x), yStart: .value(input.data.yField, low),
            yEnd: .value(input.data.yField, high)
        )
    }

    private func rule(from start: Double, to end: Double, y: Double) -> RuleMark {
        RuleMark(
            xStart: .value("Period", start), xEnd: .value("Period", end),
            y: .value(input.data.yField, y))
    }

    /// About six labelled periods, evenly spaced, always including the first.
    private func tickIndices(count: Int) -> [Double] {
        guard count > 0 else { return [] }
        let step = max(1, Int((Double(count) / 6).rounded(.up)))
        return stride(from: 0, to: count, by: step).map(Double.init)
    }

    private func tickLabel(_ index: Int, periods: [CandlePeriod]) -> String {
        guard periods.indices.contains(index) else { return "" }
        let label = periods[index].label
        if input.data.xAxis == .time, let date = ChartDates.parse(label) {
            return ChartDates.shortLabel(date)
        }
        return label
    }

    private func label(_ period: CandlePeriod) -> String {
        let text = { (value: Double) in input.data.text(value) }
        return
            "\(period.label), \(period.isUp ? "up" : "down"), open \(text(period.open)), high \(text(period.high)), low \(text(period.low)), close \(text(period.close))"
    }
}
