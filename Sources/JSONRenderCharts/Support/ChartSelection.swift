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

    /// The pie slice at `fraction` (0…1) of the full turn, clockwise from the top.
    static func slice(atFraction fraction: Double, in data: ChartData) -> String? {
        let total = data.points.reduce(0) { $0 + max($1.y, 0) }
        guard total > 0 else { return nil }
        var running = 0.0
        for point in data.points {
            running += max(point.y, 0)
            if fraction * total <= running { return point.xLabel }
        }
        return data.points.last?.xLabel
    }

    /// The label of the point closest to a selected number (time or number axis).
    static func nearestLabel(to value: Double, in data: ChartData) -> String? {
        data.points.min { lhs, rhs in
            abs((lhs.x.numeric ?? 0) - value) < abs((rhs.x.numeric ?? 0) - value)
        }?.xLabel
    }
}

/// The selection of one chart: a hovered label (local only) and a committed label (the one
/// written to state).
///
/// Hover never writes. A click, an arrow key or Escape returns the value to write, so a
/// drill-down bound to the selection does not flicker while the pointer moves. A second
/// click on the committed label deselects it (writes `null`).
public struct ChartSelectionState: Sendable, Hashable {
    public private(set) var hovered: String?
    public private(set) var committed: String?

    public init(committed: String? = nil) {
        self.committed = committed
    }

    /// The label the chart highlights: the hovered one, else the committed one.
    public var shown: String? { hovered ?? committed }

    /// Follows the pointer. Never produces a write.
    public mutating func hover(_ label: String?) {
        hovered = label
    }

    /// A click on `label`. Returns the value to write: the label, or `nil` (`null`) when
    /// the click hits the committed label again. A click on empty space writes nothing
    /// (the outer `nil`).
    public mutating func click(_ label: String?) -> String?? {
        guard let label else { return .none }
        let next: String? = label == committed ? nil : label
        committed = next
        return .some(next)
    }

    /// An arrow key: moves the committed label and returns it to write.
    public mutating func move(by step: Int, in labels: [String]) -> String?? {
        guard let next = ChartSelection.move(from: committed, by: step, in: labels) else {
            return .none
        }
        committed = next
        return .some(next)
    }

    /// Escape: clears the committed label. Writes `null` only when something was selected.
    public mutating func clear() -> String?? {
        guard committed != nil else { return .none }
        committed = nil
        return .some(nil)
    }

    /// The state changed the bound value: follow it without writing back.
    public mutating func sync(fromState label: String?) {
        committed = label
    }
}
