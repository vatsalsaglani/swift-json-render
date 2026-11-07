public import Charts
internal import Foundation
internal import JSONRenderSwiftUI
public import SwiftUI

/// Reference lines (`referenceLines`) as dashed rules with a label in the intent colour.
public struct ReferenceLineMarks: ChartContent {
    let lines: [ChartReferenceLine]
    let colors: ChartColors
    let horizontal: Bool

    public init(_ input: ChartPlotInput, horizontal: Bool = false) {
        lines = input.data.referenceLines
        colors = input.colors
        self.horizontal = horizontal
    }

    public var body: some ChartContent {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
            if horizontal {
                RuleMark(x: .value("Reference", line.value))
                    .foregroundStyle(colors.intent(line.intent))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        label(line)
                    }
            } else {
                RuleMark(y: .value("Reference", line.value))
                    .foregroundStyle(colors.intent(line.intent))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .trailing) {
                        label(line)
                    }
            }
        }
    }

    @ViewBuilder
    private func label(_ line: ChartReferenceLine) -> some View {
        if let text = line.label {
            Text(text)
                .font(colors.tokens.axisFont)
                .foregroundStyle(colors.intent(line.intent))
        }
    }
}

extension View {
    /// The default axes: a value axis with 3–5 nice ticks and hairline grid lines, a
    /// category axis without grid lines, tabular digits, both hidden for `variant: minimal`.
    /// `horizontal` puts the values on x. `aligned` (horizontal only) puts the category
    /// labels on the leading edge with `.aligned`, so short rows keep their label beside the
    /// row (box plot, waterfall).
    @ViewBuilder
    public func jrValueAxes(
        _ input: ChartPlotInput, horizontal: Bool = false, aligned: Bool = false
    ) -> some View {
        let tokens = input.tokens
        let format = input.data.axisFormat
        let visibility: Visibility = input.hidesAxes ? .hidden : .automatic
        if horizontal {
            self
                .chartXScale(domain: input.yDomain)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(tokens.gridline)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(format.axisString(number)).font(tokens.axisFont)
                            }
                        }
                    }
                }
                .chartYAxis {
                    if aligned {
                        AxisMarks(preset: .aligned, position: .leading) { _ in
                            AxisValueLabel().font(tokens.axisFont)
                        }
                    } else {
                        AxisMarks { _ in
                            AxisValueLabel().font(tokens.axisFont)
                        }
                    }
                }
                .chartXAxis(visibility)
                .chartYAxis(visibility)
        } else {
            self
                .chartYScale(domain: input.yDomain)
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(tokens.gridline)
                        AxisValueLabel {
                            if let number = value.as(Double.self) {
                                Text(format.axisString(number)).font(tokens.axisFont)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel(collisionResolution: .greedy(minimumSpacing: 4))
                            .font(tokens.axisFont)
                    }
                }
                .chartXAxis(visibility)
                .chartYAxis(visibility)
        }
    }

    /// Series colours from the palette and the legend position from `legend`.
    public func jrSeriesLegend(_ input: ChartPlotInput) -> some View {
        self
            .chartForegroundStyleScale(domain: input.styleDomain, range: input.styleRange)
            .chartLegend(input.showsLegend ? .visible : .hidden)
            .chartLegend(
                position: input.legend == .trailing ? .trailing : .bottom, alignment: .leading)
    }

    /// Pointer selection on the x axis (see `jrPointerSelection(_:axis:)`). Kept for
    /// callers of the milestone-1 name.
    public func jrXSelection(_ input: ChartPlotInput) -> some View {
        jrPointerSelection(input, axis: .x)
    }

    /// Pointer selection: hover moves the local highlight (never state); a click commits
    /// the label under the pointer through `input.commit` (a second click deselects).
    ///
    /// Built on `chartOverlay` with `onContinuousHover` and a tap, not on
    /// `chartXSelection`: on macOS the system selection follows hover and returns to nil
    /// when the pointer leaves, so writing it to state would make a drill-down flicker.
    public func jrPointerSelection(_ input: ChartPlotInput, axis: ChartPointerAxis = .x)
        -> some View
    {
        chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            input.selection.wrappedValue = ChartPointer.label(
                                at: location, proxy: proxy, geometry: geometry, input: input,
                                axis: axis)
                        case .ended:
                            input.selection.wrappedValue = nil
                        }
                    }
                    .onTapGesture { location in
                        input.commit(
                            ChartPointer.label(
                                at: location, proxy: proxy, geometry: geometry, input: input,
                                axis: axis))
                    }
            }
        }
    }

    /// A host mark override when one is set, else `self`.
    @ViewBuilder
    public func jrMarkOverride(_ input: ChartPlotInput) -> some View {
        if let override = input.markOverride {
            override
        } else {
            self
        }
    }
}

/// The tooltip for the selected x: the `tooltip` slot, else the selected values.
public struct ChartTooltip: View {
    let input: ChartPlotInput
    let label: String

    public init(_ input: ChartPlotInput, label: String) {
        self.input = input
        self.label = label
    }

    public var body: some View {
        let points = input.data.points.filter { $0.xLabel == label }
        VStack(alignment: .leading, spacing: 2) {
            if let slot = input.tooltip, !slot.isEmpty {
                slot
            } else {
                Text(label).font(input.tokens.axisFont).foregroundStyle(.secondary)
                ForEach(points) { point in
                    Text(
                        (input.data.hasSeries || input.kind == .combo ? point.series + " " : "")
                            + input.data.text(point.y)
                    )
                    .font(input.tokens.axisFont)
                }
            }
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: input.theme.radius.control)
                .fill(input.theme.color.surfaceRaised)
                .strokeBorder(input.theme.color.hairline))
    }
}

/// Which plot dimension a pointer selects along.
public enum ChartPointerAxis: Sendable, Hashable {
    /// The x axis (vertical bars, lines, areas, scatter, histogram, heatmap columns).
    case x
    /// The y axis (horizontal bars).
    case y
    /// The angle (pie and donut slices). A pointer in a donut's hole selects nothing.
    case angle
    /// A `Double` x index into `data.categories` (candlestick periods): the label at the
    /// rounded index.
    case index
}

/// Maps a pointer location to the label of the point under it.
@MainActor enum ChartPointer {
    static func label(
        at location: CGPoint, proxy: ChartProxy, geometry: GeometryProxy, input: ChartPlotInput,
        axis: ChartPointerAxis
    ) -> String? {
        guard let anchor = proxy.plotFrame else { return nil }
        let frame = geometry[anchor]
        guard frame.contains(location) else { return nil }
        let data = input.data
        switch axis {
        case .angle:
            return sliceLabel(
                at: location, in: frame, data: data,
                innerRatio: data.options.donut ? ChartPointer.donutInnerRatio : 0)
        case .index:
            return indexLabel(proxy.value(atX: location.x - frame.minX, as: Double.self), in: data)
        case .y:
            return proxy.value(atY: location.y - frame.minY, as: String.self)
        case .x:
            let x = location.x - frame.minX
            switch data.xAxis {
            case .category:
                return proxy.value(atX: x, as: String.self)
            case .time:
                return proxy.value(atX: x, as: Date.self).flatMap {
                    ChartSelection.nearestLabel(to: $0.timeIntervalSince1970, in: data)
                }
            case .number:
                return proxy.value(atX: x, as: Double.self).flatMap {
                    ChartSelection.nearestLabel(to: $0, in: data)
                }
            }
        }
    }

    /// The inner radius of a donut, as a ratio of the outer radius (`PieChart` draws with it).
    nonisolated static let donutInnerRatio = 0.62

    /// The pie slice under `location`: slices start at 12 o'clock and run clockwise. Outside
    /// the outer radius, or inside the hole (`innerRatio` × the outer radius), it is `nil`.
    static func sliceLabel(
        at location: CGPoint, in frame: CGRect, data: ChartData, innerRatio: Double = 0
    ) -> String? {
        let dx = location.x - frame.midX
        let dy = location.y - frame.midY
        let radius = min(frame.width, frame.height) / 2
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance <= radius, distance >= radius * innerRatio else { return nil }
        var angle = atan2(dy, dx) + .pi / 2
        if angle < 0 { angle += 2 * .pi }
        return ChartSelection.slice(atFraction: angle / (2 * .pi), in: data)
    }

    /// The category at the rounded x index, or `nil` off the ends.
    static func indexLabel(_ value: Double?, in data: ChartData) -> String? {
        guard let value, value.isFinite else { return nil }
        let index = Int(value.rounded())
        return data.categories.indices.contains(index) ? data.categories[index] : nil
    }
}
