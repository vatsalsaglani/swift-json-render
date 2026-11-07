import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("$computed chart aggregations")
struct ChartFunctionsTests {
    static let rows: JSONValue = [
        ["suite": "Voice", "secs": 8.6], ["suite": "Canvas", "secs": 11.2],
        ["suite": "Voice", "secs": 1.4], ["suite": "LSP", "secs": 6.7],
        ["suite": "Canvas", "secs": "slow"], ["secs": 3],
    ]

    @Test("groupSum: sorted keys, non-numeric values ignored, first-appearance order")
    func groupSum() {
        let result = ChartFunctions.groupSum(["rows": Self.rows, "by": "suite", "value": "secs"])
        #expect(
            result == [
                ["suite": "Canvas", "secs": 11.2], ["suite": "LSP", "secs": 6.7],
                ["suite": "Voice", "secs": 10],
            ])
        let first = ChartFunctions.groupSum([
            "rows": Self.rows, "by": "suite", "value": "secs", "order": "first",
        ])
        #expect(
            first?.arrayValue?.compactMap { $0["suite"]?.stringValue } == [
                "Voice", "Canvas", "LSP",
            ])
    }

    @Test("countBy")
    func countBy() {
        let result = ChartFunctions.countBy(["rows": Self.rows, "by": "suite"])
        #expect(
            result == [
                ["suite": "Canvas", "count": 2], ["suite": "LSP", "count": 1],
                ["suite": "Voice", "count": 2],
            ])
    }

    @Test("topN: descending, rest folded into Other, other: false drops it")
    func topN() {
        let result = ChartFunctions.topN([
            "rows": Self.rows, "by": "suite", "value": "secs", "n": 1,
        ])
        #expect(result == [["suite": "Canvas", "secs": 11.2], ["suite": "Other", "secs": 16.7]])
        let noOther = ChartFunctions.topN([
            "rows": Self.rows, "by": "suite", "value": "secs", "n": 2, "other": false,
        ])
        #expect(noOther?.arrayValue?.count == 2)
        #expect(ChartFunctions.topN(["rows": Self.rows, "by": "suite", "value": "secs"]) == nil)
        #expect(
            ChartFunctions.topN([
                "rows": Self.rows, "by": "suite", "value": "secs", "n": 1, "other": "yes",
            ])
                == nil)
    }

    @Test("bucket by width and by edges")
    func bucket() {
        let values: JSONValue = [0.5, 1.2, 1.9, 2.1, 4.0]
        let byWidth = ChartFunctions.bucket(["rows": values, "width": 1])
        #expect(byWidth?.arrayValue?.compactMap { $0["count"]?.numberValue } == [1, 2, 1, 0, 1])
        #expect(byWidth?[0]?["bucket"] == "0–1")
        let byEdges = ChartFunctions.bucket(["rows": values, "edges": [0, 1, 2, 4]])
        #expect(byEdges?.arrayValue?.compactMap { $0["count"]?.numberValue } == [1, 2, 2])
        let fields = ChartFunctions.bucket(["rows": Self.rows, "by": "secs", "width": 5])
        #expect(fields?.arrayValue?.compactMap { $0["count"]?.numberValue } == [2, 2, 1])
    }

    @Test("Missing or wrong-typed arguments give undefined")
    func badArguments() {
        #expect(ChartFunctions.groupSum([:]) == nil)
        #expect(ChartFunctions.groupSum(["rows": "x", "by": "a", "value": "b"]) == nil)
        #expect(ChartFunctions.countBy(["rows": Self.rows]) == nil)
        #expect(ChartFunctions.bucket(["rows": Self.rows, "by": "secs", "width": 0]) == nil)
        #expect(ChartFunctions.bucket(["rows": Self.rows, "by": "secs"]) == nil)
        #expect(ChartFunctions.bucket(["rows": [1, 2], "edges": [2, 1]]) == nil)
    }

    @Test("Empty rows give empty arrays")
    func empty() {
        #expect(ChartFunctions.groupSum(["rows": [], "by": "a", "value": "b"]) == [])
        #expect(ChartFunctions.countBy(["rows": [], "by": "a"]) == [])
        #expect(ChartFunctions.topN(["rows": [], "by": "a", "value": "b", "n": 3]) == [])
        #expect(ChartFunctions.bucket(["rows": [], "width": 1]) == [])
    }

    @Test("Registered on the chart catalog and listed in the prompt")
    func registered() throws {
        let catalog = try Catalog.charts
        #expect(
            Array(catalog.functionOrder.prefix(4)) == ["groupSum", "countBy", "topN", "bucket"])
        let prompt = catalog.prompt()
        #expect(prompt.contains("groupSum"))
        #expect(prompt.contains("bucket"))
    }
}
