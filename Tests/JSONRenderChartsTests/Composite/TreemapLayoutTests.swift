import CoreGraphics
import Foundation
import Testing

@testable import JSONRenderCharts

/// A small deterministic generator (SplitMix64), so every run checks the same inputs.
struct SplitMix64: RandomNumberGenerator {
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

@Suite("TreemapLayout")
struct TreemapLayoutTests {
    static let seed: UInt64 = 0x7265_6D61_7033_6421
    static let iterations = 500

    /// One random case: 1…200 log-uniform values (1e-3…1e3) and a rect with aspect 0.2…5.
    struct Case {
        var values: [Double]
        var rect: CGRect
    }

    static func cases() -> [Case] {
        var generator = SplitMix64(seed: seed)
        return (0..<iterations).map { _ in
            let count = Int.random(in: 1...200, using: &generator)
            let values = (0..<count).map { _ in
                exp(Double.random(in: log(1e-3)...log(1e3), using: &generator))
            }
            let aspect = exp(Double.random(in: log(0.2)...log(5.0), using: &generator))
            let height = Double.random(in: 80...400, using: &generator)
            let rect = CGRect(
                x: Double.random(in: -50...50, using: &generator),
                y: Double.random(in: -50...50, using: &generator), width: height * aspect,
                height: height)
            return Case(values: values, rect: rect)
        }
    }

    @Test("500 seeded inputs: exact tiling, no overlap, proportional areas, order, aspect")
    func properties() {
        var worstOverlap = 0.0
        var worstAreaError = 0.0
        var squarifiedWins = 0
        for (iteration, input) in Self.cases().enumerated() {
            let note = Comment(
                rawValue:
                    "seed \(String(Self.seed, radix: 16)) iteration \(iteration) count \(input.values.count)"
            )
            let cells = TreemapLayout.squarify(values: input.values, in: input.rect)
            let rect = input.rect
            let rectArea = Double(rect.width * rect.height)
            let sum = input.values.reduce(0, +)
            // Order: one cell per value, in input order.
            #expect(cells.map(\.index) == Array(input.values.indices), note)
            // Tiling: the areas add up to the rect, and the union's bounds are the rect.
            let areas = cells.map { Double($0.rect.width * $0.rect.height) }
            #expect(abs(areas.reduce(0, +) - rectArea) <= 1e-6 * rectArea, note)
            let union = cells.map(\.rect).reduce(CGRect.null) { $0.union($1) }
            #expect(abs(union.minX - rect.minX) < 1e-9, note)
            #expect(abs(union.minY - rect.minY) < 1e-9, note)
            #expect(abs(union.maxX - rect.maxX) < 1e-9, note)
            #expect(abs(union.maxY - rect.maxY) < 1e-9, note)
            // Proportion: each cell's share of the rect is its value's share of the sum.
            for (cell, value) in zip(cells, input.values) {
                let error = abs(Double(cell.rect.width * cell.rect.height) / rectArea - value / sum)
                worstAreaError = max(worstAreaError, error)
                #expect(error <= 1e-6, note)
            }
            // No overlap: pairwise intersections have no area.
            for first in cells.indices {
                for second in cells.indices where second > first {
                    let overlap = cells[first].rect.intersection(cells[second].rect)
                    let area = overlap.isNull ? 0 : Double(overlap.width * overlap.height)
                    worstOverlap = max(worstOverlap, area)
                    #expect(area < 1e-9, note)
                }
            }
            // Aspect: never worse than slice-and-dice for the same input.
            let squarified = TreemapLayout.worstAspectRatio(cells)
            let sliced = TreemapLayout.worstAspectRatio(
                TreemapLayout.sliceAndDice(values: input.values, in: rect))
            #expect(squarified <= sliced * (1 + 1e-9), note)
            if squarified < sliced { squarifiedWins += 1 }
        }
        print(
            "TreemapLayout property suite: seed 0x\(String(Self.seed, radix: 16)), \(Self.iterations) inputs, worst overlap \(worstOverlap), worst area error \(worstAreaError), squarified strictly better in \(squarifiedWins)"
        )
    }

    @Test("The layout is deterministic")
    func deterministic() {
        for input in Self.cases().prefix(20) {
            #expect(
                TreemapLayout.squarify(values: input.values, in: input.rect)
                    == TreemapLayout.squarify(values: input.values, in: input.rect))
        }
    }

    @Test("Zero, negative and non-finite values get empty cells; the rest still tile")
    func degenerate() {
        let rect = CGRect(x: 0, y: 0, width: 300, height: 200)
        let values = [6.0, 0, -3, .nan, 3, .infinity, 1]
        let cells = TreemapLayout.squarify(values: values, in: rect)
        #expect(cells.count == values.count)
        for index in [1, 2, 3, 5] {
            #expect(cells[index].rect.size == .zero)
        }
        let area = cells.map { Double($0.rect.width * $0.rect.height) }.reduce(0, +)
        #expect(abs(area - 60_000) < 1e-6)
        #expect(abs(Double(cells[0].rect.width * cells[0].rect.height) - 36_000) < 1e-6)
        // Nothing to draw: every cell is empty.
        #expect(
            TreemapLayout.squarify(values: [0, -1], in: rect).allSatisfy { $0.rect.size == .zero })
        #expect(TreemapLayout.squarify(values: [], in: rect).isEmpty)
        #expect(
            TreemapLayout.squarify(values: [1, 2], in: .zero).allSatisfy {
                $0.rect.size == .zero
            })
    }

    @Test("The textbook example (Bruls et al.): 6 6 4 3 2 2 1 in 6 × 4")
    func textbook() {
        let cells = TreemapLayout.squarify(
            values: [6, 6, 4, 3, 2, 2, 1], in: CGRect(x: 0, y: 0, width: 6, height: 4))
        // The first row holds the two 6s in a column of width 3.
        #expect(cells[0].rect == CGRect(x: 0, y: 0, width: 3, height: 2))
        #expect(cells[1].rect == CGRect(x: 0, y: 2, width: 3, height: 2))
        #expect(TreemapLayout.worstAspectRatio(cells) < 3)
    }

    @Test("The gap insets every cell by half the gap")
    func gap() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let plain = TreemapLayout.squarify(values: [3, 2, 1], in: rect)
        let gapped = TreemapLayout.squarify(values: [3, 2, 1], in: rect, gap: 2)
        for (lhs, rhs) in zip(plain, gapped) {
            #expect(rhs.rect == lhs.rect.insetBy(dx: 1, dy: 1))
        }
        // A cell smaller than the gap keeps its centre and gets no size.
        let tiny = TreemapLayout.squarify(values: [1_000_000, 1], in: rect, gap: 4)
        #expect(tiny[1].rect.width == 0 || tiny[1].rect.height == 0)
    }

    @Test("Grouped: the groups tile the rect; each group's values tile its group")
    func grouped() {
        var generator = SplitMix64(seed: Self.seed ^ 0xFF)
        for _ in 0..<100 {
            let groups = (0..<Int.random(in: 1...8, using: &generator)).map { _ in
                (0..<Int.random(in: 1...25, using: &generator)).map { _ in
                    Double.random(in: 0.1...100, using: &generator)
                }
            }
            let rect = CGRect(x: 0, y: 0, width: 480, height: 240)
            let layout = TreemapLayout.squarify(groups: groups, in: rect)
            let total: Double = groups.flatMap(\.self).reduce(0, +)
            let full: Double = 480 * 240
            let groupArea: Double = layout.groups.map { Double($0.rect.width * $0.rect.height) }
                .reduce(0, +)
            #expect(abs(groupArea - full) < 1e-6 * full)
            for (index, group) in groups.enumerated() {
                let outer = layout.groups[index].rect
                let inner = layout.values[index]
                #expect(inner.count == group.count)
                let area: Double = inner.map { Double($0.rect.width * $0.rect.height) }
                    .reduce(0, +)
                let outerArea = Double(outer.width * outer.height)
                #expect(abs(area - outerArea) < 1e-6 * full)
                for (cell, value) in zip(inner, group) {
                    #expect(outer.insetBy(dx: -1e-9, dy: -1e-9).contains(cell.rect))
                    let share = Double(cell.rect.width * cell.rect.height) / full
                    #expect(abs(share - value / total) < 1e-6)
                }
            }
        }
    }
}
