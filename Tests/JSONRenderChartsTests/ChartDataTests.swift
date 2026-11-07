import Foundation
import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("ChartData decoding")
struct ChartDataTests {
    static let runs: JSONValue = [
        ["run": "4208", "result": "Passed", "n": 1210],
        ["run": "4208", "result": "Failed", "n": 7],
        ["run": "4209", "result": "Passed", "n": 1225],
        ["run": "4209", "result": "Skipped", "n": 12],
        ["run": "4210", "result": "Passed", "n": 1230],
    ]

    @Test("Fields, series order of first appearance, bars from zero")
    func barFields() {
        let (data, warnings) = ChartData.make(
            props: ["data": Self.runs, "x": "run", "y": "n", "series": "result"], kind: .bar)
        #expect(warnings.isEmpty)
        #expect(data.categories == ["4208", "4209", "4210"])
        #expect(data.series == ["Passed", "Failed", "Skipped"])
        #expect(data.points.count == 5)
        #expect(data.yDomain == 0...1_500)
        #expect(data.hasSeries)
    }

    @Test("Stacked bars carry a base and use the totals for the domain")
    func stacked() {
        let (data, _) = ChartData.make(
            props: [
                "data": Self.runs, "x": "run", "y": "n", "series": "result", "layout": "stacked",
            ], kind: .bar)
        let failed = data.points.first { $0.series == "Failed" }
        #expect(failed?.base == 1_210)
        #expect(data.dataRange == 0...1_237)
    }

    @Test("Normalized bars are percentages; an all-zero bar is skipped")
    func normalized() {
        let rows: JSONValue = [
            ["x": "a", "s": "p", "y": 3], ["x": "a", "s": "q", "y": 1],
            ["x": "b", "s": "p", "y": 0], ["x": "b", "s": "q", "y": 0],
        ]
        let (data, _) = ChartData.make(
            props: ["data": rows, "x": "x", "y": "y", "series": "s", "layout": "normalized"],
            kind: .bar)
        #expect(data.categories == ["a"])
        #expect(data.points.map(\.y) == [75, 25])
        #expect(data.axisFormat == .percent)
        #expect(data.yDomain == 0...100)
    }

    @Test("Sort and limit fold the rest into Other")
    func ranked() {
        let rows: JSONValue = [
            ["suite": "A", "secs": 3.8], ["suite": "B", "secs": 11.2], ["suite": "C", "secs": 6.7],
            ["suite": "D", "secs": 8.6], ["suite": "E", "secs": 1.5], ["suite": "F", "secs": 1.2],
        ]
        let (data, warnings) = ChartData.make(
            props: [
                "data": rows, "x": "suite", "y": "secs", "orientation": "horizontal",
                "sort": "desc",
                "limit": 4,
            ], kind: .bar)
        #expect(data.categories == ["B", "D", "C", "A", "Other (2)"])
        #expect(data.points.last?.isOther == true)
        #expect(abs((data.points.last?.y ?? 0) - 2.7) < 1e-9)
        #expect(warnings.contains(.foldedIntoOther(2)))
        #expect(data.options.orientation == .horizontal)
    }

    @Test("Rows without x or with a non-numeric y are skipped and counted")
    func skipped() {
        let rows: JSONValue = [["x": "a", "y": 1], ["y": 2], ["x": "c", "y": "n/a"], "junk"]
        let (data, warnings) = ChartData.make(props: ["data": rows], kind: .bar)
        #expect(data.points.count == 1)
        #expect(warnings.contains(.skippedRows(3)))
    }

    @Test("ISO dates become a sorted time axis; mixed values fall back to categories")
    func timeAxis() {
        let rows: JSONValue = [
            ["day": "2026-11-07", "v": 3], ["day": "2026-11-05", "v": 1],
            ["day": "2026-11-06T10:00:00Z", "v": 2],
        ]
        let (data, _) = ChartData.make(props: ["data": rows, "x": "day", "y": "v"], kind: .line)
        #expect(data.xAxis == .time)
        #expect(data.points.map(\.y) == [1, 2, 3])
        let mixed: JSONValue = [["day": "2026-11-07", "v": 3], ["day": "Mon", "v": 1]]
        let (fallback, warnings) = ChartData.make(
            props: ["data": mixed, "x": "day", "y": "v"], kind: .line)
        #expect(fallback.xAxis == .category)
        #expect(warnings.contains(.mixedTimeAxis))
    }

    @Test("Reference lines and a fixed yDomain shape the domain")
    func domains() {
        let rows: JSONValue = [["x": "a", "y": 40], ["x": "b", "y": 45]]
        let (withLine, _) = ChartData.make(
            props: [
                "data": rows,
                "referenceLines": [["value": 60, "label": "Budget", "intent": "risk"]],
            ],
            kind: .line)
        #expect(withLine.yDomain == 0...60)
        #expect(withLine.referenceLines.first?.intent == .critical)
        let (fixed, _) = ChartData.make(props: ["data": rows, "yDomain": [0, 50]], kind: .line)
        #expect(fixed.yDomain == 0...50)
        #expect(fixed.yDomainIsFixed)
    }

    @Test("More than 12 series blocks the chart")
    func seriesBudget() {
        let rows = JSONValue.array((0..<13).map { ["x": "a", "y": 1, "s": .string("s\($0)")] })
        let (data, _) = ChartData.make(props: ["data": rows, "series": "s"], kind: .bar)
        #expect(data.blocking == .tooManySeries(13))
    }

    @Test("Unknown format warns and prints plainly")
    func unknownFormat() {
        let (data, warnings) = ChartData.make(
            props: ["data": [["x": "a", "y": 1]], "format": "money"], kind: .bar)
        #expect(data.format == .number)
        #expect(warnings.contains(.unknownFormat))
    }
}
