import Foundation
import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("Default VoiceOver summaries")
struct ChartSummaryTests {
    let locale = Locale(identifier: "en_US")

    @Test("Bar chart: count, highest value and where")
    func bar() {
        let rows = JSONValue.array(
            [
                ("4204", 44), ("4205", 37), ("4206", 40), ("4207", 34), ("4208", 39), ("4209", 35),
                ("4210", 70),
            ]
            .map { ["run": .string($0.0), "secs": .number(Double($0.1))] })
        let (data, _) = ChartData.make(
            props: ["data": rows, "x": "run", "y": "secs", "unit": "s"], kind: .bar)
        #expect(
            ChartSummary.text(for: data, locale: locale)
                == "Bar chart, 7 runs, highest 70 s at run 4210")
    }

    @Test("Stacked bars use totals and name the series count")
    func stacked() {
        let (data, _) = ChartData.make(
            props: [
                "data": ChartDataTests.runs, "x": "run", "y": "n", "series": "result",
                "layout": "stacked",
            ], kind: .bar)
        #expect(
            ChartSummary.text(for: data, locale: locale)
                == "Bar chart, 3 runs, 3 series, highest 1,237 at run 4209")
    }

    @Test("Pie: parts, largest slice and its share")
    func pie() {
        let rows: JSONValue = [["p": "Terminals", "mb": 61], ["p": "Editor", "mb": 39]]
        let (data, _) = ChartData.make(
            props: ["data": rows, "label": "p", "value": "mb", "unit": "MB"], kind: .pie)
        #expect(
            ChartSummary.text(for: data, locale: locale)
                == "Pie chart, 2 parts, largest Terminals 61 MB, 61 %")
    }

    @Test("Empty data")
    func empty() {
        let (data, _) = ChartData.make(props: [:], kind: .line)
        #expect(ChartSummary.text(for: data, locale: locale) == "Line chart, no data")
    }

    @Test("Plurals of field names")
    func plurals() {
        #expect(ChartSummary.plural("run", count: 2) == "runs")
        #expect(ChartSummary.plural("day", count: 2) == "days")
        #expect(ChartSummary.plural("category", count: 2) == "categories")
        #expect(ChartSummary.plural("suites", count: 2) == "suites")
        #expect(ChartSummary.plural("run", count: 1) == "run")
    }
}
