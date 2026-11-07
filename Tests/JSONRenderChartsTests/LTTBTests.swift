import Foundation
import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("LTTB downsampling")
struct LTTBTests {
    func series(_ count: Int, seed: UInt64) -> (x: [Double], y: [Double]) {
        var generator = SeededGenerator(seed: seed)
        let x = (0..<count).map(Double.init)
        let y = (0..<count).map {
            sin(Double($0) / 40) * 50 + Double.random(in: -5...5, using: &generator)
        }
        return (x, y)
    }

    @Test(
        "Exact output count, endpoints kept, x order preserved", arguments: [1_001, 2_500, 5_000])
    func shape(count: Int) {
        let (x, y) = series(count, seed: UInt64(count))
        let kept = LTTB.indices(x: x, y: y, threshold: 1_000)
        #expect(kept.count == 1_000)
        #expect(kept.first == 0)
        #expect(kept.last == count - 1)
        #expect(zip(kept, kept.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("Short inputs and small thresholds are unchanged")
    func passthrough() {
        let (x, y) = series(50, seed: 1)
        #expect(LTTB.indices(x: x, y: y, threshold: 100) == Array(0..<50))
        #expect(LTTB.indices(x: x, y: y, threshold: 2) == Array(0..<50))
    }

    @Test("A spike survives downsampling")
    func keepsPeaks() {
        var y = Array(repeating: 1.0, count: 3_000)
        y[1_234] = 500
        let x = y.indices.map(Double.init)
        let kept = LTTB.indices(x: x, y: y, threshold: 300)
        #expect(kept.contains(1_234))
    }

    @Test("Line charts over 1,000 points draw 1,000")
    func lineChartBudget() {
        let rows: [JSONValueRow] = (0..<2_400).map {
            ["t": .number(Double($0)), "v": .number(Double($0 % 50))]
        }
        let (data, warnings) = ChartData.make(
            props: ["data": .array(rows.map { .object($0) }), "x": "t", "y": "v"], kind: .line)
        #expect(data.points.count == 1_000)
        #expect(warnings.contains(.downsampled(from: 2_400, to: 1_000)))
    }
}

/// A deterministic generator (SplitMix64) for property-style tests.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

typealias JSONValueRow = [String: JSONValue]
