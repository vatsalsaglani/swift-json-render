import Foundation
import JSONRenderCore
import SwiftUI
import Testing

@testable import JSONRenderCharts

@Suite("Accessibility descriptors and mark labels")
@MainActor
struct ChartDescriptorTests {
    @Test("A categorical chart: one series per series name, categorical x, numeric y")
    func categorical() {
        let (data, _) = ChartData.make(
            props: ["data": ChartDataTests.runs, "x": "run", "y": "n", "series": "result"],
            kind: .bar)
        let descriptor = ChartAccessibilityDescriptor(
            data: data, title: "Tests", summary: "summary"
        ).makeChartDescriptor()
        #expect(descriptor.title == "Tests")
        #expect(descriptor.summary == "summary")
        #expect(descriptor.series.map(\.name) == ["Passed", "Failed", "Skipped"])
        #expect(descriptor.series.first?.dataPoints.count == 3)
        let axis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(axis?.categoryOrder == ["4208", "4209", "4210"])
        #expect(descriptor.yAxis?.range == data.yDomain)
    }

    @Test("A time chart: continuous series on a numeric x axis")
    func time() {
        let (data, _) = ChartData.make(
            props: [
                "data": [["d": "2026-11-05", "v": 1], ["d": "2026-11-07", "v": 2]], "x": "d",
                "y": "v",
            ], kind: .line)
        let descriptor = ChartAccessibilityDescriptor(data: data, title: nil, summary: "s")
            .makeChartDescriptor()
        #expect(descriptor.title == "Line chart")
        #expect(descriptor.xAxis is AXNumericDataAxisDescriptor)
        #expect(descriptor.series.first?.isContinuous == true)
    }

    @Test("Mark labels carry the series, the x and the formatted value")
    func labels() {
        let rows: JSONValue = [["run": "4210", "secs": 70]]
        let (data, _) = ChartData.make(
            props: ["data": rows, "x": "run", "y": "secs", "unit": "s"], kind: .bar)
        let locale = Locale(identifier: "en_US")
        #expect(
            ChartAccessibilityDescriptor.label(data.points[0], data: data, locale: locale)
                == "run 4210, 70 s")
        let (stacked, _) = ChartData.make(
            props: ["data": ChartDataTests.runs, "x": "run", "y": "n", "series": "result"],
            kind: .bar)
        #expect(
            ChartAccessibilityDescriptor.label(stacked.points[0], data: stacked, locale: locale)
                == "Passed, run 4208, 1,210")
    }

    @Test("Table rows match the drawn points")
    func tableRows() {
        let (data, _) = ChartData.make(
            props: ["data": ChartSamples.memory, "label": "part", "value": "mb", "unit": "MB"],
            kind: .pie)
        let rows = data.tableRows(locale: Locale(identifier: "en_US"))
        #expect(rows.count == data.points.count)
        #expect(rows.first?.x == "Terminals")
        #expect(rows.first?.value == "61 MB")
    }
}
