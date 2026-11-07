public import Charts
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
    /// `horizontal` puts the values on x.
    @ViewBuilder
    public func jrValueAxes(_ input: ChartPlotInput, horizontal: Bool = false) -> some View {
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
                    AxisMarks { _ in
                        AxisValueLabel().font(tokens.axisFont)
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

    /// Selection along x: a category, a date (snapped to the nearest point) or a number.
    @ViewBuilder
    public func jrXSelection(_ input: ChartPlotInput) -> some View {
        let data = input.data
        let selection = input.selection
        switch data.xAxis {
        case .category:
            self.chartXSelection(value: selection)
        case .time:
            self.chartXSelection(
                value: Binding<Date?>(
                    get: {
                        guard let label = selection.wrappedValue,
                            let point = data.points.first(where: { $0.xLabel == label }),
                            case .date(let date) = point.x
                        else { return nil }
                        return date
                    },
                    set: { date in
                        selection.wrappedValue = date.flatMap {
                            ChartSelection.nearestLabel(to: $0.timeIntervalSince1970, in: data)
                        }
                    }))
        case .number:
            self.chartXSelection(
                value: Binding<Double?>(
                    get: {
                        guard let label = selection.wrappedValue else { return nil }
                        return data.points.first(where: { $0.xLabel == label })?.x.numeric
                    },
                    set: { number in
                        selection.wrappedValue = number.flatMap {
                            ChartSelection.nearestLabel(to: $0, in: data)
                        }
                    }))
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
