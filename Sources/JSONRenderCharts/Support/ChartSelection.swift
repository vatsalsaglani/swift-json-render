public import JSONRenderCore
public import JSONRenderSwiftUI

/// The selection write-back: the chart writes the selected x (or slice label) to the state
/// path bound to its `selection` prop, through the renderer's binding writer.
public enum ChartSelection {
    /// The JSON value to write for a selected label: the number for a numeric axis, the
    /// label text otherwise, `null` when nothing is selected.
    public static func value(for label: String?, in data: ChartData) -> JSONValue {
        guard let label else { return .null }
        if data.xAxis == .number,
            let point = data.points.first(where: { $0.xLabel == label }),
            let number = point.x.numeric
        {
            return .number(number)
        }
        return .string(label)
    }

    /// Writes `label` to the pointer bound to `selection`. Does nothing without a binding.
    @MainActor public static func write(
        _ label: String?, data: ChartData, bindings: [String: JSONPointer],
        writer: JRBindingWriter
    ) {
        guard let pointer = bindings["selection"] else { return }
        writer(pointer, value(for: label, in: data))
    }

    /// The label after `current` in `labels`, moving by `step` and wrapping at the ends.
    public static func move(from current: String?, by step: Int, in labels: [String])
        -> String?
    {
        guard !labels.isEmpty else { return nil }
        guard let current, let index = labels.firstIndex(of: current) else {
            return step >= 0 ? labels.first : labels.last
        }
        let next = (index + step + labels.count) % labels.count
        return labels[next]
    }

    /// The selectable labels of a chart, in order.
    static func labels(in data: ChartData) -> [String] {
        if !data.categories.isEmpty, data.kind != .heatmap { return data.categories }
        var seen = Set<String>()
        return data.points.map(\.xLabel).filter { seen.insert($0).inserted }
    }

    /// The label of the point closest to a selected number (time or number axis).
    static func nearestLabel(to value: Double, in data: ChartData) -> String? {
        data.points.min { lhs, rhs in
            abs((lhs.x.numeric ?? 0) - value) < abs((rhs.x.numeric ?? 0) - value)
        }?.xLabel
    }
}
