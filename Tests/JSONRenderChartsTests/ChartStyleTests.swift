import Charts
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderCharts

@Suite("Chart styles and mark overrides")
@MainActor
struct ChartStyleTests {
    @MainActor final class Counter {
        var calls = 0
        var kinds: [ChartKind] = []
        var points = 0

        func record() { calls += 1 }
    }

    struct RecordingStyle: ChartStyle {
        let counter: Counter

        func makeBody(configuration: ChartStyleConfiguration) -> some View {
            counter.calls += 1
            counter.kinds.append(configuration.kind)
            counter.points = configuration.data.points.count
            return configuration.marks.overlay(alignment: .topTrailing) { Text("styled") }
        }
    }

    struct TintStyle: ChartStyle, Equatable {
        var opacity: Double

        func makeBody(configuration: ChartStyleConfiguration) -> some View {
            configuration.marks.opacity(opacity)
        }
    }

    func render(_ view: some View) {
        _ = ImageRenderer(content: view.frame(width: 400)).cgImage
    }

    func bar() -> AnyView {
        AnyView(
            BarChart(
                context: JRRenderContext(
                    id: "c", props: ["data": .some(ChartDataTests.runs), "x": "run", "y": "n"])))
    }

    @Test("A style receives the resolved data and the default marks")
    func styleIsUsed() {
        let counter = Counter()
        render(bar().jrChartStyle(RecordingStyle(counter: counter), for: .bar))
        #expect(counter.calls >= 1)
        #expect(counter.kinds.first == .bar)
        #expect(counter.points == 3)
    }

    @Test("A style for another chart type is not used")
    func styleIsScoped() {
        let counter = Counter()
        render(bar().jrChartStyle(RecordingStyle(counter: counter), for: [.line, .pie]))
        #expect(counter.calls == 0)
    }

    @Test("A mark override replaces only the marks")
    func markOverride() {
        let counter = Counter()
        render(
            bar().jrChartMarks(for: .bar) { data in
                let _ = counter.record()
                ForEach(data.points) { point in
                    PointMark(x: .value("x", point.xLabel), y: .value("y", point.y))
                }
            })
        #expect(counter.calls >= 1)
    }

    @Test("Style sets compare Equatable styles by value and others by type")
    func equality() {
        var lhs = ChartStyleSet()
        var rhs = ChartStyleSet()
        #expect(lhs == rhs)
        lhs.styles[.bar] = AnyChartStyle(TintStyle(opacity: 0.5))
        rhs.styles[.bar] = AnyChartStyle(TintStyle(opacity: 0.5))
        #expect(lhs == rhs)
        rhs.styles[.bar] = AnyChartStyle(TintStyle(opacity: 0.8))
        #expect(lhs != rhs)
        let counter = Counter()
        lhs.styles[.bar] = AnyChartStyle(RecordingStyle(counter: counter))
        rhs.styles[.bar] = AnyChartStyle(RecordingStyle(counter: Counter()))
        #expect(lhs == rhs)
        rhs.styles[.line] = AnyChartStyle(DefaultChartStyle())
        #expect(lhs != rhs)
        #expect(lhs.hasStyle(for: .bar))
        #expect(!lhs.hasMarks(for: .bar))
    }

    @Test("A blocking rule shows the rule text, not marks")
    func blockingRule() {
        let counter = Counter()
        let rows = JSONValue.array([["l": "a", "v": -1], ["l": "b", "v": 2]])
        render(
            PieChart(
                context: JRRenderContext(
                    id: "p", props: ["data": .some(rows), "label": "l", "value": "v"])
            )
            .jrChartStyle(RecordingStyle(counter: counter), for: .pie))
        #expect(counter.calls == 0)
    }
}
