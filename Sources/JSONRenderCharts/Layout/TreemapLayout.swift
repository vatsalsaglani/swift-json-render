public import CoreGraphics

/// The squarified treemap layout of Bruls, Huizing and van Wijk ("Squarified Treemaps",
/// 2000): a pure function from values and a rectangle to one rectangle per value.
///
/// The layout sorts the values in descending order (ties keep input order), lays rows along
/// the shorter side of the free rectangle, and adds a value to the current row only while
/// the row's worst aspect ratio does not get worse. It is iterative (no recursion), so its
/// depth does not depend on the input.
///
/// Values that are zero, negative or not finite get an empty rectangle at the origin of
/// `rect`. The non-empty cells tile `rect` exactly before the gap is applied; the gap is an
/// inset of `gap / 2` on every side of every cell, so neighbours are `gap` apart.
public struct TreemapLayout: Sendable {
    /// One laid-out value. `index` is the value's position in the input.
    public struct Cell: Sendable, Hashable {
        public let index: Int
        public let rect: CGRect

        public init(index: Int, rect: CGRect) {
            self.index = index
            self.rect = rect
        }
    }

    /// The squarified layout. The result has one cell per value, in input order.
    public static func squarify(values: [Double], in rect: CGRect, gap: CGFloat = 0) -> [Cell] {
        let frame = rect.standardized
        let clean = values.map { $0.isFinite && $0 > 0 ? $0 : 0 }
        let total = clean.reduce(0, +)
        var rects = Array(repeating: CGRect(origin: frame.origin, size: .zero), count: values.count)
        guard total > 0, total.isFinite, frame.width > 0, frame.height > 0 else {
            return cells(rects)
        }
        let order = clean.indices.filter { clean[$0] > 0 }.sorted { lhs, rhs in
            clean[lhs] != clean[rhs] ? clean[lhs] > clean[rhs] : lhs < rhs
        }
        let scale = Double(frame.width) * Double(frame.height) / total
        let areas = order.map { clean[$0] * scale }
        var free = Box(frame)
        var start = 0
        while start < order.count {
            let side = min(free.width, free.height)
            var end = start + 1
            var sum = areas[start]
            var smallest = areas[start]
            var largest = areas[start]
            var worst = worstRatio(sum: sum, smallest: smallest, largest: largest, side: side)
            while end < order.count {
                let area = areas[end]
                let candidate = worstRatio(
                    sum: sum + area, smallest: min(smallest, area), largest: max(largest, area),
                    side: side)
                if candidate > worst { break }
                sum += area
                smallest = min(smallest, area)
                largest = max(largest, area)
                worst = candidate
                end += 1
            }
            let isLast = end == order.count
            free.placeRow(
                areas: areas[start..<end], indices: order[start..<end], sum: sum, isLast: isLast,
                into: &rects)
            start = end
        }
        return cells(rects.map { inset($0, by: gap / 2) })
    }

    /// The slice-and-dice layout: one strip per value along the longer side, in input order.
    /// The reference the squarified layout is compared against.
    public static func sliceAndDice(values: [Double], in rect: CGRect) -> [Cell] {
        let frame = rect.standardized
        let clean = values.map { $0.isFinite && $0 > 0 ? $0 : 0 }
        let total = clean.reduce(0, +)
        var rects = Array(repeating: CGRect(origin: frame.origin, size: .zero), count: values.count)
        guard total > 0, total.isFinite, frame.width > 0, frame.height > 0 else {
            return cells(rects)
        }
        let horizontal = frame.width >= frame.height
        let length = Double(horizontal ? frame.width : frame.height)
        let origin = Double(horizontal ? frame.minX : frame.minY)
        let last = clean.lastIndex(where: { $0 > 0 })
        var running = 0.0
        var position = origin
        for (index, value) in clean.enumerated() where value > 0 {
            running += value
            let end = index == last ? origin + length : origin + length * running / total
            rects[index] =
                horizontal
                ? CGRect(x: position, y: frame.minY, width: end - position, height: frame.height)
                : CGRect(x: frame.minX, y: position, width: frame.width, height: end - position)
            position = end
        }
        return cells(rects)
    }

    /// The largest `max(width / height, height / width)` over the non-empty cells; `1` when
    /// every cell is empty.
    public static func worstAspectRatio(_ cells: [Cell]) -> Double {
        var worst = 1.0
        for cell in cells where cell.rect.width > 0 && cell.rect.height > 0 {
            let width = Double(cell.rect.width)
            let height = Double(cell.rect.height)
            worst = max(worst, width / height, height / width)
        }
        return worst
    }

    /// A two-level layout: the groups are squarified by their sums, then each group's values
    /// are squarified inside the group's cell. The gap applies to the values only, so every
    /// value cell is `gap` from each neighbour, inside its group or across groups.
    ///
    /// - Returns: the group cells (no gap) and, per group, the value cells (with the gap).
    public static func squarify(groups: [[Double]], in rect: CGRect, gap: CGFloat = 0)
        -> (groups: [Cell], values: [[Cell]])
    {
        let sums = groups.map { values in
            values.reduce(0) { $0 + ($1.isFinite && $1 > 0 ? $1 : 0) }
        }
        let outer = squarify(values: sums, in: rect)
        let inner = groups.indices.map { index in
            squarify(values: groups[index], in: outer[index].rect, gap: gap)
        }
        return (outer, inner)
    }

    // MARK: - Implementation

    /// The worst aspect ratio of a row with total area `sum` laid along `side`
    /// (Bruls et al., equation 1).
    static func worstRatio(sum: Double, smallest: Double, largest: Double, side: Double)
        -> Double
    {
        guard sum > 0, smallest > 0, side > 0 else { return .infinity }
        let side2 = side * side
        let sum2 = sum * sum
        return max(side2 * largest / sum2, sum2 / (side2 * smallest))
    }

    /// The free rectangle, in `Double` so that edges are computed once and shared exactly
    /// by neighbouring cells.
    struct Box {
        var minX: Double
        var minY: Double
        var maxX: Double
        var maxY: Double

        init(_ rect: CGRect) {
            minX = Double(rect.minX)
            minY = Double(rect.minY)
            maxX = Double(rect.maxX)
            maxY = Double(rect.maxY)
        }

        var width: Double { max(maxX - minX, 0) }
        var height: Double { max(maxY - minY, 0) }

        /// Places one row along the shorter side and removes it from the free rectangle.
        /// The last row takes the whole free rectangle, so rounding never leaves a sliver.
        mutating func placeRow(
            areas: ArraySlice<Double>, indices: ArraySlice<Int>, sum: Double, isLast: Bool,
            into rects: inout [CGRect]
        ) {
            let vertical = width >= height  // a column at the left edge
            let side = vertical ? height : width
            let freeLength = vertical ? width : height
            let thickness = isLast ? freeLength : min(sum / side, freeLength)
            var running = 0.0
            var position = vertical ? minY : minX
            let sideStart = position
            for (offset, index) in zip(areas.indices, indices) {
                running += areas[offset]
                let end =
                    offset == areas.indices.last
                    ? sideStart + side : sideStart + side * running / sum
                rects[index] =
                    vertical
                    ? CGRect(x: minX, y: position, width: thickness, height: end - position)
                    : CGRect(x: position, y: minY, width: end - position, height: thickness)
                position = end
            }
            if vertical {
                minX = isLast ? maxX : minX + thickness
            } else {
                minY = isLast ? maxY : minY + thickness
            }
        }
    }

    private static func cells(_ rects: [CGRect]) -> [Cell] {
        rects.enumerated().map { Cell(index: $0.offset, rect: $0.element) }
    }

    /// `rect` inset by `amount` on each side; a cell smaller than the inset keeps its centre
    /// and gets no size. Empty cells stay empty.
    static func inset(_ rect: CGRect, by amount: CGFloat) -> CGRect {
        guard amount > 0, rect.width > 0, rect.height > 0 else { return rect }
        let width = max(rect.width - 2 * amount, 0)
        let height = max(rect.height - 2 * amount, 0)
        return CGRect(
            x: rect.midX - width / 2, y: rect.midY - height / 2, width: width, height: height)
    }
}
