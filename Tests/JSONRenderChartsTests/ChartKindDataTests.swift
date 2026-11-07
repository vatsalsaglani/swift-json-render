import Foundation
import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("ChartData for each chart kind")
struct ChartKindDataTests {
    @Test("Pie: largest first, Other after maxSlices − 1, negatives block")
    func pie() {
        let (data, warnings) = ChartData.make(
            props: ["data": ChartSamples.memory, "label": "part", "value": "mb"], kind: .pie)
        #expect(
            data.points.map(\.xLabel) == [
                "Terminals", "Editor", "Board", "Voice", "Search", "Other",
            ])
        #expect(data.points.last?.y == 4)
        #expect(data.points.last?.isOther == true)
        #expect(warnings.contains(.foldedIntoOther(2)))
        let (negative, _) = ChartData.make(
            props: [
                "data": [["l": "a", "v": -1], ["l": "b", "v": 2]], "label": "l", "value": "v",
            ],
            kind: .pie)
        #expect(negative.blocking == .negativeSlice)
        let (single, singleWarnings) = ChartData.make(
            props: ["data": [["l": "a", "v": 2]], "label": "l", "value": "v"], kind: .pie)
        #expect(single.points.count == 1)
        #expect(singleWarnings.contains(.singleSlice))
    }

    @Test("Area: stacked totals set the domain; normalized is 0…100")
    func area() {
        let (stacked, _) = ChartData.make(
            props: [
                "data": ChartSamples.tokens, "x": "day", "y": "k", "series": "agent",
                "layout": "stacked",
            ],
            kind: .area)
        // Sunday: 60 + 24 + 12.
        #expect(stacked.dataRange?.upperBound == 96)
        #expect(stacked.yDomain == 0...100)
        let (normalized, _) = ChartData.make(
            props: [
                "data": ChartSamples.tokens, "x": "day", "y": "k", "series": "agent",
                "layout": "normalized",
            ], kind: .area)
        #expect(normalized.yDomain == 0...100)
        let monday = normalized.points.filter { $0.xLabel == "Mon" }.map(\.y).reduce(0, +)
        #expect(abs(monday - 100) < 1e-9)
    }

    @Test("Scatter: numeric x, least-squares fit, bubble size range")
    func scatter() {
        let rows: JSONValue = [
            ["x": 1, "y": 3, "s": 2], ["x": 2, "y": 5, "s": 8], ["x": 3, "y": 7, "s": 4],
            ["x": "n/a", "y": 1],
        ]
        let (data, warnings) = ChartData.make(
            props: ["data": rows, "trend": "linear", "size": "s"], kind: .scatter)
        #expect(data.points.count == 3)
        #expect(warnings.contains(.skippedRows(1)))
        #expect(abs((data.options.fit?.slope ?? 0) - 2) < 1e-9)
        #expect(abs((data.options.fit?.intercept ?? 0) - 1) < 1e-9)
        #expect(data.options.sizeRange == 2...8)
        #expect(data.xAxis == .number)
        // Rows skipped for two reasons give one count.
        let mixed: JSONValue = [["x": 1, "y": 3], ["x": "n/a", "y": 1], ["y": 2]]
        let (_, mixedWarnings) = ChartData.make(props: ["data": mixed], kind: .scatter)
        #expect(
            mixedWarnings.filter { if case .skippedRows = $0 { true } else { false } } == [
                .skippedRows(2)
            ])
    }

    @Test("Heatmap grid: columns and rows in first-appearance order; value range")
    func heatmap() {
        let (data, _) = ChartData.make(
            props: ["data": ChartSamples.activity, "x": "hour", "y": "day", "value": "n"],
            kind: .heatmap)
        #expect(data.categories.count == 12)
        #expect(data.rows == ["Mon", "Tue", "Wed", "Thu"])
        #expect(data.options.valueRange == 0...12)
    }

    @Test("Heatmap calendar: weeks by weekdays from ISO dates")
    func calendar() {
        let (data, _) = ChartData.make(
            props: [
                "data": ChartSamples.calendar, "x": "date", "y": "date", "value": "n",
                "layout": "calendar",
            ],
            kind: .heatmap)
        #expect(data.rows == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        // 1 Oct 2026 is a Thursday; 56 days span 9 ISO weeks.
        #expect(data.categories.count == 9)
        #expect(data.categories.first == "Sep 28")
        #expect(data.points.first?.row == "Thu")
    }

    @Test("Histogram: Freedman–Diaconis bins with a nice width that cover every value")
    func histogram() {
        let (data, _) = ChartData.make(
            props: ["values": ChartSamples.durations, "unit": "s"], kind: .histogram)
        let total = data.points.reduce(0) { $0 + $1.y }
        #expect(total == 48)
        #expect(data.points.count >= 4)
        #expect((data.points.first?.x.numeric ?? 1) <= 0.6)
        #expect((data.points.last?.xEnd ?? 0) >= 6.7)
        #expect(data.options.xUnit == "s")
        let (percent, _) = ChartData.make(
            props: ["values": ChartSamples.durations, "mode": "percent", "bins": 5],
            kind: .histogram)
        #expect(abs(percent.points.reduce(0) { $0 + $1.y } - 100) < 1e-9)
        #expect(percent.format == .percent)
    }

    @Test("Freedman–Diaconis falls back to Sturges for a zero IQR")
    func binRules() {
        #expect(HistogramBins.freedmanDiaconisBins([1, 1, 1, 1, 1, 1, 1, 9]) == 4)
        #expect(HistogramBins.freedmanDiaconisBins([5]) == 1)
        let bins = HistogramBins.bins([0, 10], low: 0, high: 10, count: 5)
        #expect(bins.map(\.count).reduce(0, +) == 2)
        #expect(bins.last?.upper ?? 0 >= 10)
    }

    @Test("Sparkline: values in order, raw range, downsampled over 1,000")
    func sparkline() {
        let (data, _) = ChartData.make(props: ["values": [8, 10, 6, 14]], kind: .sparkline)
        #expect(data.points.map(\.y) == [8, 10, 6, 14])
        #expect(data.dataRange == 6...14)
        let long = JSONValue.array((0..<1_500).map { .number(Double($0 % 37)) })
        let (big, warnings) = ChartData.make(props: ["values": long], kind: .sparkline)
        #expect(big.points.count == 1_000)
        #expect(warnings.contains(.downsampled(from: 1_500, to: 1_000)))
    }

    @Test("Combo: bars and line series on one domain")
    func combo() {
        let (data, _) = ChartData.make(
            props: ["data": ChartSamples.days, "x": "day", "bars": "secs", "line": "avg"],
            kind: .combo)
        #expect(data.series == ["secs", "avg"])
        #expect(data.points.filter { $0.series == "secs" }.count == 7)
        #expect(data.points.filter { $0.series == "avg" }.count == 7)
        #expect(data.yDomain == 0...60)
    }

    @Test("Gauge model: fraction, bands, target, texts")
    func gauge() {
        let model = GaugeModel.make(props: [
            "value": 3.6, "max": 5, "format": "currency:USD", "label": "Voice budget",
            "bands": [
                ["to": 4.5, "intent": "warn"], ["to": 3.5, "intent": "good"],
                ["to": 5, "intent": "risk"],
            ],
            "target": 4,
        ])
        let locale = Locale(identifier: "en_US")
        #expect(abs(model.fraction - 0.72) < 1e-9)
        #expect(model.bands.map(\.upTo) == [3.5, 4.5, 5])
        #expect(model.currentIntent == .warning)
        #expect(abs((model.targetFraction ?? 0) - 0.8) < 1e-9)
        #expect(model.valueText(locale: locale) == "$3.60")
        #expect(model.rangeText(locale: locale) == "of $5.00 · 72 %")
        #expect(
            model.summary(locale: locale)
                == "Gauge, Voice budget, $3.60 of $5.00 · 72 %, target $4.00")
        let clamped = GaugeModel.make(props: ["value": 150, "min": 10, "max": 5])
        #expect(clamped.max == 11)
        #expect(clamped.fraction == 1)
    }
}
