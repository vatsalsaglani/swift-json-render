public import JSONRenderCore

/// The `$computed` aggregations that turn state rows into chart rows. Specs never contain
/// code; hosts register these on the chart catalog.
///
/// Arguments are resolved values. Missing or wrong-typed arguments give `nil` (undefined)
/// and nothing else. Output order is deterministic: keys sorted by code point, or in order
/// of first appearance with `order: "first"`.
public enum ChartFunctions {
    /// Registers `groupSum`, `countBy`, `topN` and `bucket`.
    public static func register(into catalog: inout Catalog) {
        catalog.function(
            "groupSum",
            description:
                "args { rows, by, value, order? }: one row per distinct `by` with the sum of `value`.",
            groupSum)
        catalog.function(
            "countBy",
            description: "args { rows, by, order? }: one row per distinct `by` with its `count`.",
            countBy)
        catalog.function(
            "topN",
            description:
                "args { rows, by, value, n, other? }: the n largest sums, descending; the rest as one \"Other\" row unless other is false.",
            topN)
        catalog.function(
            "bucket",
            description:
                "args { rows, by, width | edges }: { bucket, count } rows for a histogram-like bar chart.",
            bucket)
    }

    /// `groupSum(rows, by, value, order?)` → `[{ <by>: key, <value>: sum }]`.
    public static let groupSum: ComputedFunction = { args in
        guard let rows = rows(args), let by = string(args, "by"), let value = string(args, "value")
        else { return nil }
        let groups = sums(rows, by: by, value: value)
        let keys = ordered(groups.order, first: string(args, "order") == "first")
        return .array(
            keys.map { key in
                .object([by: .string(key), value: .number(groups.sums[key] ?? 0)])
            })
    }

    /// `countBy(rows, by, order?)` → `[{ <by>: key, count: n }]`.
    public static let countBy: ComputedFunction = { args in
        guard let rows = rows(args), let by = string(args, "by") else { return nil }
        var counts: [String: Int] = [:]
        var order: [String] = []
        for row in rows {
            guard let key = ChartValues.text(row[by]) else { continue }
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        let keys = ordered(order, first: string(args, "order") == "first")
        return .array(
            keys.map { key in
                .object([by: .string(key), "count": .number(Double(counts[key] ?? 0))])
            })
    }

    /// `topN(rows, by, value, n, other = true)` → the n largest sums, descending (ties by
    /// key), plus `{ <by>: "Other", <value>: rest }` when rows remain and `other` is true.
    public static let topN: ComputedFunction = { args in
        guard let rows = rows(args), let by = string(args, "by"), let value = string(args, "value"),
            case .number(let rawN)?? = args["n"], rawN.isFinite, rawN >= 0
        else { return nil }
        var includeOther = true
        switch args["other"] ?? nil {
        case nil: break
        case .bool(let flag)?: includeOther = flag
        default: return nil
        }
        let n = Int(rawN.rounded(.down))
        let groups = sums(rows, by: by, value: value)
        let sorted = groups.order.sorted { lhs, rhs in
            let left = groups.sums[lhs] ?? 0
            let right = groups.sums[rhs] ?? 0
            return left != right ? left > right : lhs < rhs
        }
        var result: [JSONValue] = sorted.prefix(n).map { key in
            .object([by: .string(key), value: .number(groups.sums[key] ?? 0)])
        }
        let rest = sorted.dropFirst(n)
        if includeOther, !rest.isEmpty {
            let total = rest.reduce(0) { $0 + (groups.sums[$1] ?? 0) }
            result.append(.object([by: "Other", value: .number(total)]))
        }
        return .array(result)
    }

    /// `bucket(rows, by, width | edges)` → `[{ bucket: "lo–hi", count }]`, ascending. With
    /// `width`, every bucket from the smallest to the largest value is listed (at most
    /// 1,000). With `edges` (ascending numbers), values outside the edges are not counted;
    /// the last bucket includes its upper edge. Rows may be numbers when `by` is absent.
    public static let bucket: ComputedFunction = { args in
        guard let rows = rows(args) else { return nil }
        let by = string(args, "by")
        if args["by"] != nil, by == nil { return nil }
        let values: [Double] = rows.compactMap { row in
            by.map { ChartValues.number(row[$0]) } ?? ChartValues.number(row)
        }
        if case .number(let width)?? = args["width"] {
            guard width.isFinite, width > 0 else { return nil }
            guard let low = values.min(), let high = values.max() else { return .array([]) }
            let first = (low / width).rounded(.down)
            let last = (high / width).rounded(.down)
            guard last - first < 1000 else { return nil }
            var counts = Array(repeating: 0, count: Int(last - first) + 1)
            for value in values { counts[Int((value / width).rounded(.down) - first)] += 1 }
            return .array(
                counts.enumerated().map { index, count in
                    let lower = (first + Double(index)) * width
                    return row(lower, lower + width, count)
                })
        }
        guard case .array(let rawEdges)?? = args["edges"] else { return nil }
        let edges = rawEdges.compactMap(\.numberValue)
        guard edges.count == rawEdges.count, edges.count >= 2, edges == edges.sorted(),
            Set(edges).count == edges.count
        else { return nil }
        var counts = Array(repeating: 0, count: edges.count - 1)
        for value in values {
            guard value >= edges[0], value <= edges[edges.count - 1] else { continue }
            let index =
                edges.lastIndex(where: { $0 <= value }).map { min($0, counts.count - 1) } ?? 0
            counts[index] += 1
        }
        return .array(
            counts.enumerated().map { index, count in row(edges[index], edges[index + 1], count) })
    }

    // MARK: - Helpers

    private static func rows(_ args: [String: JSONValue?]) -> [JSONValue]? {
        guard case .array(let items)?? = args["rows"] else { return nil }
        return items
    }

    private static func string(_ args: [String: JSONValue?], _ name: String) -> String? {
        guard case .string(let text)?? = args[name], !text.isEmpty else { return nil }
        return text
    }

    private static func sums(_ rows: [JSONValue], by: String, value: String)
        -> (order: [String], sums: [String: Double])
    {
        var order: [String] = []
        var totals: [String: Double] = [:]
        for row in rows {
            guard let key = ChartValues.text(row[by]) else { continue }
            if totals[key] == nil {
                order.append(key)
                totals[key] = 0
            }
            if let number = ChartValues.number(row[value]) { totals[key, default: 0] += number }
        }
        return (order, totals)
    }

    private static func ordered(_ keys: [String], first: Bool) -> [String] {
        first ? keys : keys.sorted()
    }

    private static func row(_ lower: Double, _ upper: Double, _ count: Int) -> JSONValue {
        .object([
            "bucket": .string(
                JSONValue.number(lower).jsString + "–" + JSONValue.number(upper).jsString),
            "from": .number(lower), "to": .number(upper), "count": .number(Double(count)),
        ])
    }
}
