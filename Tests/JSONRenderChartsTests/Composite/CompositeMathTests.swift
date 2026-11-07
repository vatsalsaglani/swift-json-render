import Foundation
import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("Waterfall math")
struct WaterfallMathTests {
    @Test("Running totals; a first subtotal sets the start; later subtotals show the total")
    func runningTotals() {
        let (data, warnings) = WaterfallData.make(
            props: [
                "data": .some(CompositeSamples.memorySteps), "label": "label", "value": "value",
                "subtotals": ["Start", "Now"],
            ])
        #expect(warnings.isEmpty)
        #expect(data.categories == ["Start", "Terminals", "Editor", "Pool cap", "Voice", "Now"])
        #expect(data.points.map(\.y) == [112, 32, 19, -24, 12, 151])
        #expect(data.points.map { $0.base ?? -1 } == [0, 112, 144, 163, 139, 0])
        #expect(
            data.points.map(\.series) == ["Total", "Change", "Change", "Change", "Change", "Total"])
        // Bars from zero: the domain holds 0 and the highest running total (163).
        #expect(data.yDomain.lowerBound == 0)
        #expect(data.yDomain.upperBound >= 163)
    }

    @Test("start draws a Start bar; a subtotal's own value is ignored after a change")
    func start() {
        let (data, _) = WaterfallData.make(
            props: [
                "data": [["l": "a", "v": 5], ["l": "sub", "v": 999], ["l": "b", "v": -2]],
                "label": "l", "value": "v", "start": 10, "subtotals": ["sub"],
            ])
        #expect(data.categories == ["Start", "a", "sub", "b"])
        #expect(data.points.map(\.y) == [10, 5, 15, -2])
        #expect(data.points.map { $0.base ?? -1 } == [0, 10, 0, 15])
    }

    @Test("More than 12 steps fold into Other; a final subtotal stays last")
    func fold() {
        var rows: [JSONValue] = [["l": "Start", "v": 100]]
        rows += (1...15).map { ["l": .string("s\($0)"), "v": .number(Double($0))] }
        rows.append(["l": "End", "v": 0])
        let (data, warnings) = WaterfallData.make(
            props: [
                "data": .some(.array(rows)), "label": "l", "value": "v",
                "subtotals": ["Start", "End"],
            ])
        #expect(data.points.count == CompositeBudgets.maxWaterfallSteps)
        #expect(data.points.last?.xLabel == "End")
        let other = data.points[data.points.count - 2]
        #expect(other.isOther)
        // Kept: s1…s9 (Start + 9 = 10 rows); folded: s10…s15 = 75.
        #expect(other.xLabel == "Other (6)")
        #expect(other.y == 75)
        // The total is unchanged by the fold: 100 + 120.
        #expect(data.points.last?.y == 220)
        #expect(warnings.contains { if case .foldedIntoOther = $0 { true } else { false } })
    }

    @Test("Repeated labels become unique; rows without a value are skipped and counted")
    func uniqueAndSkipped() {
        let (data, warnings) = WaterfallData.make(
            props: [
                "data": [["l": "a", "v": 1], ["l": "a", "v": 2], ["l": "b"], "junk"],
                "label": "l", "value": "v",
            ])
        #expect(data.categories == ["a", "a (2)"])
        #expect(warnings.contains(.skippedRows(2)))
    }

    @Test("Signed labels use a true minus sign")
    func signed() {
        #expect(CompositeData.signed(32, format: .number) == "+32")
        #expect(CompositeData.signed(-24, format: .number) == "\u{2212}24")
        #expect(CompositeData.signed(0, format: .number) == "0")
    }
}

@Suite("Funnel")
struct FunnelTests {
    @Test("Percent of the first stage and step-to-step percent")
    func percents() {
        let values = [1296.0, 1284, 1277, 79]
        let shares = FunnelData.shareOfFirst(values)
        #expect(shares[0] == 100)
        #expect(abs(shares[3] - 79 / 1296 * 100) < 1e-9)
        let steps = FunnelData.stepPercents(values)
        #expect(steps.count == 3)
        #expect(abs((steps[0] ?? 0) - 1284 / 1296 * 100) < 1e-9)
        #expect(abs((steps[2] ?? 0) - 79 / 1277 * 100) < 1e-9)
        #expect(FunnelData.stepPercents([0, 5]) == [nil])
        #expect(FunnelData.shareOfFirst([0, 5]) == [0, 0])
    }

    @Test("The first larger stage is found")
    func monotonic() {
        #expect(FunnelData.firstIncrease([10, 8, 8, 3]) == nil)
        #expect(FunnelData.firstIncrease([10, 8, 9, 3]) == 2)
        #expect(FunnelData.firstIncrease([]) == nil)
    }

    @Test("sort: desc orders widest first; more than 8 stages fold into Other")
    func sortAndFold() {
        let (sorted, _) = FunnelData.make(
            props: [
                "data": [["l": "a", "v": 1], ["l": "b", "v": 5], ["l": "c", "v": 3]], "label": "l",
                "value": "v", "sort": "desc",
            ])
        #expect(sorted.categories == ["b", "c", "a"])
        let rows: [JSONValue] = (0..<11).map {
            ["l": .string("s\($0)"), "v": .number(Double(100 - $0))]
        }
        let (folded, warnings) = FunnelData.make(
            props: ["data": .some(.array(rows)), "label": "l", "value": "v"])
        #expect(folded.points.count == CompositeBudgets.maxFunnelStages)
        #expect(folded.points.last?.xLabel == "Other (4)")
        #expect(folded.points.last?.y == 90)
        #expect(folded.points.last?.isOther == true)
        #expect(warnings.contains(.foldedIntoOther(4)))
    }

    @Test("The validator rejects a larger stage unless sort is set")
    func rule() throws {
        let catalog = try Catalog.charts
        func spec(_ extra: [String: JSONValue]) -> Spec {
            var props: [String: JSONValue] = [
                "data": [["l": "a", "v": 5], ["l": "b", "v": 7]], "label": "l", "value": "v",
            ]
            props.merge(extra) { $1 }
            return Spec(root: "f", elements: ["f": UIElement(type: "Funnel", props: props)])
        }
        #expect(!catalog.validate(spec([:])).errors.isEmpty)
        #expect(catalog.validate(spec(["sort": "none"])).errors.isEmpty)
    }
}

@Suite("BoxPlot statistics")
struct BoxPlotStatsTests {
    @Test("Tukey hinges on an odd and an even count")
    func hinges() throws {
        // Odd (9): halves include the median.
        let odd = try #require(BoxPlotStats.tukey([1.2, 1.4, 1.8, 2.1, 2.4, 2.6, 3.1, 3.4, 9.5]))
        #expect(odd.median == 2.4)
        #expect(odd.q1 == 1.8)
        #expect(odd.q3 == 3.1)
        #expect(odd.outliers == [9.5])
        #expect(odd.low == 1.2)
        #expect(odd.high == 3.4)
        // Even (8): halves of four.
        let even = try #require(BoxPlotStats.tukey([7.9, 2.1, 2.4, 2.9, 3.3, 3.8, 4.4, 5.1]))
        #expect(even.median == (3.3 + 3.8) / 2)
        #expect(even.q1 == (2.4 + 2.9) / 2)
        #expect(even.q3 == (4.4 + 5.1) / 2)
    }

    @Test("Fewer than four values, all equal, and empty")
    func small() throws {
        let one = try #require(BoxPlotStats.tukey([3]))
        #expect([one.low, one.q1, one.median, one.q3, one.high] == [3, 3, 3, 3, 3])
        let two = try #require(BoxPlotStats.tukey([1, 5]))
        #expect(two.q1 == 1 && two.median == 3 && two.q3 == 5)
        let three = try #require(BoxPlotStats.tukey([1, 2, 9]))
        #expect(three.q1 == 1.5 && three.median == 2 && three.q3 == 5.5)
        let equal = try #require(BoxPlotStats.tukey(Array(repeating: 4, count: 7)))
        #expect(equal.outliers.isEmpty)
        #expect([equal.low, equal.q1, equal.median, equal.q3, equal.high] == [4, 4, 4, 4, 4])
        #expect(BoxPlotStats.tukey([]) == nil)
        #expect(BoxPlotStats.tukey([.nan]) == nil)
    }

    @Test("Without outliers the whiskers reach the minimum and maximum")
    func noOutliers() throws {
        let stats = try #require(BoxPlotStats.tukey([1, 2, 3, 4, 50], outliers: false))
        #expect(stats.high == 50)
        #expect(stats.outliers.isEmpty)
    }

    @Test("Data: raw and precomputed rows; an unordered precomputed row is skipped")
    func data() {
        let (data, warnings) = BoxPlotData.make(
            props: ["data": .some(CompositeSamples.suites), "group": "suite"])
        #expect(warnings.isEmpty)
        #expect(data.categories == ["Canvas", "Voice", "LSP", "MDX"])
        let groups = BoxPlotData.groups(in: data)
        #expect(groups.count == 4)
        #expect(
            groups[3].stats
                == BoxPlotStats(low: 0.4, q1: 0.7, median: 0.9, q3: 1.2, high: 1.7, outliers: [3.1])
        )
        #expect(data.yDomain.lowerBound <= 0.4)
        #expect(data.yDomain.upperBound >= 9.5)
        let (bad, badWarnings) = BoxPlotData.make(
            props: [
                "data": [["g": "x", "min": 3, "q1": 1, "median": 2, "q3": 4, "max": 5]],
                "group": "g",
            ])
        #expect(bad.isEmpty)
        #expect(badWarnings.contains(.skippedRows(1)))
    }
}

@Suite("Candlestick")
struct CandlestickTests {
    @Test("Up and hollow: a period that closes down is hollow")
    func hollow() {
        let (data, _) = CandlestickData.make(
            props: ["data": .some(CompositeSamples.spend), "x": "day"])
        let periods = CandlestickData.periods(in: data)
        #expect(periods.count == 10)
        #expect(periods[0].isUp && !periods[0].isHollow)
        #expect(periods[2].isHollow)  // D3: 12.5 → 11.5
        #expect(periods.filter(\.isHollow).map(\.label) == ["D3", "D4", "D8"])
        let flat = CandlePeriod(label: "x", open: 2, high: 3, low: 1, close: 2)
        #expect(flat.isUp)
    }

    @Test("More than 180 periods keep the last 180; dates sort")
    func lastPeriods() {
        let rows: [JSONValue] = (0..<200).reversed().map { index in
            let date = Date(timeIntervalSince1970: 1_767_225_600 + Double(index) * 86_400)
            return [
                "d": .string(date.formatted(.iso8601.year().month().day())),
                "open": .number(Double(index)), "high": .number(Double(index) + 2),
                "low": .number(Double(index) - 1), "close": .number(Double(index) + 1),
            ]
        }
        let (data, warnings) = CandlestickData.make(props: ["data": .some(.array(rows)), "x": "d"])
        let periods = CandlestickData.periods(in: data)
        #expect(data.xAxis == .time)
        #expect(periods.count == CompositeBudgets.maxCandlestickPeriods)
        #expect(periods.first?.open == 20)
        #expect(periods.last?.open == 199)
        #expect(warnings.contains(.downsampled(from: 200, to: 180)))
    }

    @Test("Low and high widen to hold open and close; the validator reports it")
    func tolerant() throws {
        let (data, _) = CandlestickData.make(
            props: ["data": [["x": "a", "open": 5, "high": 4, "low": 3, "close": 2]], "x": "x"])
        let period = try #require(CandlestickData.periods(in: data).first)
        #expect(period.high == 5 && period.low == 2)
        let spec = Spec(
            root: "c",
            elements: [
                "c": UIElement(
                    type: "Candlestick",
                    props: [
                        "data": [["x": "a", "open": 5, "high": 4, "low": 3, "close": 2]], "x": "x",
                    ])
            ])
        #expect(
            try Catalog.charts.validate(spec).errors.contains {
                $0.rule == CompositeChartRules.name
            })
    }
}

@Suite("Treemap data")
struct TreemapDataTests {
    @Test("Largest first, groups in first-appearance order, non-positive values skipped")
    func make() {
        let (data, warnings) = TreemapData.make(
            props: [
                "data": [
                    ["l": "a", "v": 2, "g": "x"], ["l": "b", "v": 9, "g": "y"],
                    ["l": "c", "v": 0, "g": "x"], ["l": "d", "v": -4, "g": "x"],
                    ["l": "e", "v": 5, "g": "x"],
                ],
                "label": "l", "value": "v", "group": "g",
            ])
        #expect(data.categories == ["b", "e", "a"])
        #expect(data.series == ["y", "x"])
        #expect(warnings.contains(.skippedRows(2)))
    }

    @Test("More than 200 cells fold into one Other cell with the rest's sum")
    func fold() {
        let rows: [JSONValue] = (1...250).map {
            ["l": .string("c\($0)"), "v": .number(Double($0))]
        }
        let (data, warnings) = TreemapData.make(
            props: ["data": .some(.array(rows)), "label": "l", "value": "v"])
        #expect(data.points.count == CompositeBudgets.maxTreemapCells)
        let other = data.points.last
        #expect(other?.isOther == true)
        #expect(other?.xLabel == "Other (51)")
        #expect(other?.y == Double((1...51).reduce(0, +)))
        #expect(warnings.contains(.foldedIntoOther(51)))
        #expect(data.series.isEmpty)
    }

    @Test("Tiles: grouped cells stay inside their group; flat with maxDepth 1")
    func tiles() {
        let (data, _) = TreemapData.make(
            props: [
                "data": .some(CompositeSamples.modules), "label": "module", "value": "lines",
                "group": "area",
            ])
        let rect = CGRect(x: 0, y: 0, width: 400, height: 160)
        let grouped = TreemapData.tiles(for: data, in: rect, maxDepth: 2, gap: 0)
        #expect(grouped.count == 6)
        let area = grouped.map { Double($0.rect.width * $0.rect.height) }.reduce(0, +)
        #expect(abs(area - 64_000) < 1e-6)
        let flat = TreemapData.tiles(for: data, in: rect, maxDepth: 1, gap: 2)
        #expect(flat.map(\.point.xLabel) == data.points.map(\.xLabel))
    }

    @Test("The validator rejects zero and negative values")
    func rule() throws {
        let catalog = try Catalog.charts
        for bad in [0.0, -3] {
            let spec = Spec(
                root: "t",
                elements: [
                    "t": UIElement(
                        type: "Treemap",
                        props: [
                            "data": [["l": "a", "v": 4], ["l": "b", "v": .number(bad)]],
                            "label": "l", "value": "v",
                        ])
                ])
            let errors = catalog.validate(spec).errors
            #expect(errors.contains { $0.rule == CompositeChartRules.name && $0.elementKey == "t" })
        }
    }
}
