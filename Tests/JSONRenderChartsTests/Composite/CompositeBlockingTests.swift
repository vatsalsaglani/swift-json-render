import JSONRenderCore
import Testing

@testable import JSONRenderCharts

/// jr-2p items 12 and 15: the composite blocking rules are `ChartWarning` cases, and the
/// waterfall connectors run from bar edge to bar edge.
@Suite("Composite blocking warnings")
struct CompositeBlockingTests {
    static func boxRows(_ count: Int) -> JSONValue {
        .array((0..<count).map { ["group": .string("g\($0)"), "values": [1, 2, 3, 4, 5]] })
    }

    @Test("BoxPlot: more than 20 groups blocks with tooManyGroups")
    func boxPlotGroups() {
        let (data, warnings) = BoxPlotData.make(props: ["data": Self.boxRows(21)])
        #expect(warnings.contains(.tooManyGroups(21)))
        #expect(data.blocking == .tooManyGroups(21))
        #expect(ChartWarning.tooManyGroups(21).isBlocking)
        #expect(
            ChartWarning.tooManyGroups(21).message
                == "This box plot has 21 groups; the limit is 20.")
        let (small, _) = BoxPlotData.make(props: ["data": Self.boxRows(20)])
        #expect(small.blocking == nil)
    }

    @Test("Funnel: a larger stage blocks with stageIncrease unless sort is set")
    func funnelIncrease() {
        let rows: JSONValue = [
            ["label": "a", "value": 10], ["label": "b", "value": 8], ["label": "c", "value": 9],
        ]
        let (data, warnings) = FunnelData.make(props: ["data": rows])
        #expect(warnings.contains(.stageIncrease(3)))
        #expect(data.blocking == .stageIncrease(3))
        #expect(ChartWarning.stageIncrease(3).isBlocking)
        #expect(
            ChartWarning.stageIncrease(3).message
                == "Stage 3 is larger than the stage before it; set sort: \"none\" to allow it.")
        let (allowed, _) = FunnelData.make(props: ["data": rows, "sort": "none"])
        #expect(allowed.blocking == nil)
        let (sorted, _) = FunnelData.make(props: ["data": rows, "sort": "desc"])
        #expect(sorted.blocking == nil)
    }

    @Test("Waterfall connectors run from the far edge of a bar to the near edge of the next")
    func waterfallConnectors() {
        let segments = WaterfallConnectors.segments(levels: [10, 14, 12])
        #expect(segments.count == 2)
        #expect(segments.map(\.level) == [10, 14])
        for (index, segment) in segments.enumerated() {
            #expect(abs(segment.start - (Double(index) + 0.31)) < 1e-9)
            #expect(abs(segment.end - (Double(index + 1) - 0.31)) < 1e-9)
        }
        #expect(WaterfallConnectors.segments(levels: [5]).isEmpty)
        #expect(WaterfallConnectors.segments(levels: []).isEmpty)
    }
}
