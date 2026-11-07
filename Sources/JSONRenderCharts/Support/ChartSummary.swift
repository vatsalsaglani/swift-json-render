public import Foundation

/// The default VoiceOver summary, used when the spec has no `summary` prop. Example:
/// "Bar chart, 7 runs, highest 70 s at run 4210".
public enum ChartSummary {
    public static func text(for data: ChartData, locale: Locale = .current) -> String {
        let name = data.kind.spokenName
        guard !data.points.isEmpty else { return "\(name), no data" }
        let value = { (number: Double) in data.text(number, locale: locale) }
        switch data.kind {
        case .pie:
            let total = data.points.reduce(0) { $0 + $1.y }
            guard let top = data.points.max(by: { $0.y < $1.y }) else { return name }
            let share = total > 0 ? top.y / total * 100 : 0
            return
                "\(name), \(data.points.count) parts, largest \(top.xLabel) \(value(top.y)), \(ChartValueFormat.percent.axisString(share, locale: locale))"
        case .heatmap:
            guard let top = data.points.max(by: { $0.y < $1.y }) else { return name }
            let place = [top.row, top.xLabel].compactMap(\.self).joined(separator: ", ")
            return
                "\(name), \(data.rows.count) rows by \(data.categories.count) columns, highest \(value(top.y)) at \(place)"
        case .histogram:
            guard let top = data.points.max(by: { $0.y < $1.y }) else { return name }
            let xFormat = data.options.xFormat
            let range =
                xFormat.string(top.x.numeric ?? 0, unit: nil, locale: locale) + " to "
                + xFormat.string(top.xEnd ?? 0, unit: data.options.xUnit, locale: locale)
            return "\(name), \(data.points.count) bins, most values from \(range)"
        case .sparkline:
            let values = data.points.map(\.y)
            guard let last = values.last, let low = values.min(), let high = values.max() else {
                return name
            }
            return
                "\(name), \(values.count) values, last \(value(last)), range \(value(low)) to \(value(high))"
        case .scatter:
            var text = "\(name), \(data.points.count) points"
            if let fit = data.options.fit {
                text += fit.slope >= 0 ? ", trend rising" : ", trend falling"
            }
            return text
        default:
            return seriesSummary(data, name: name, value: value)
        }
    }

    private static func seriesSummary(
        _ data: ChartData, name: String, value: (Double) -> String
    ) -> String {
        let stacked =
            (data.kind == .bar && data.options.barLayout == .stacked)
            || (data.kind == .area && data.options.areaLayout == .stacked)
        // Totals per x for stacked layouts; the largest single value otherwise.
        var order: [String] = []
        var best: [String: Double] = [:]
        for point in data.points where data.kind != .combo || point.series == data.yField {
            if best[point.xLabel] == nil { order.append(point.xLabel) }
            best[point.xLabel] =
                stacked
                ? (best[point.xLabel] ?? 0) + point.y
                : max(best[point.xLabel] ?? -.infinity, point.y)
        }
        let noun = plural(data.xField, count: order.count)
        var text = "\(name), \(order.count) \(noun)"
        if data.hasSeries, data.kind != .combo { text += ", \(data.series.count) series" }
        if let top = order.max(by: { (best[$0] ?? 0) < (best[$1] ?? 0) }), let peak = best[top] {
            let label = data.xAxis == .category ? "\(data.xField) \(top)" : top
            text += ", highest \(value(peak)) at \(label)"
        }
        return text
    }

    /// A naive English plural of a field name ("run" → "runs", "day" → "days").
    static func plural(_ word: String, count: Int) -> String {
        guard count != 1, !word.isEmpty else { return word }
        if word.hasSuffix("s") { return word }
        if word.hasSuffix("y"), let before = word.dropLast().last, !"aeiou".contains(before) {
            return word.dropLast() + "ies"
        }
        return word + "s"
    }
}
