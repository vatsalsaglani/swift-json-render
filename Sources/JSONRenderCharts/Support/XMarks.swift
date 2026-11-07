public import Charts
internal import Foundation
internal import SwiftUI

/// Marks positioned on an x axis that may hold categories, dates or numbers. Each function
/// returns one concrete mark type, so chart bodies stay single-path.
public enum XMarks {
    public static func line(_ point: ChartPoint, data: ChartData) -> LineMark {
        let y = PlottableValue.value(data.yField, point.y)
        let series = PlottableValue.value("Series", point.series)
        switch point.x {
        case .category(let value):
            return LineMark(x: .value(data.xField, value), y: y, series: series)
        case .date(let value): return LineMark(x: .value(data.xField, value), y: y, series: series)
        case .number(let value):
            return LineMark(x: .value(data.xField, value), y: y, series: series)
        }
    }

    public static func point(_ point: ChartPoint, data: ChartData) -> PointMark {
        let y = PlottableValue.value(data.yField, point.y)
        switch point.x {
        case .category(let value): return PointMark(x: .value(data.xField, value), y: y)
        case .date(let value): return PointMark(x: .value(data.xField, value), y: y)
        case .number(let value): return PointMark(x: .value(data.xField, value), y: y)
        }
    }

    public static func area(
        _ point: ChartPoint, data: ChartData, stacking: MarkStackingMethod
    ) -> AreaMark {
        let y = PlottableValue.value(data.yField, point.y)
        switch point.x {
        case .category(let value):
            return AreaMark(x: .value(data.xField, value), y: y, stacking: stacking)
        case .date(let value):
            return AreaMark(x: .value(data.xField, value), y: y, stacking: stacking)
        case .number(let value):
            return AreaMark(x: .value(data.xField, value), y: y, stacking: stacking)
        }
    }

    /// A vertical rule at `x` (selection indicator).
    public static func rule(_ x: ChartXValue, data: ChartData) -> RuleMark {
        switch x {
        case .category(let value): return RuleMark(x: .value(data.xField, value))
        case .date(let value): return RuleMark(x: .value(data.xField, value))
        case .number(let value): return RuleMark(x: .value(data.xField, value))
        }
    }

    /// The selected point's x, when the selection names a point.
    public static func selectedX(_ input: ChartPlotInput) -> ChartXValue? {
        guard let label = input.selection.wrappedValue else { return nil }
        return input.data.points.first(where: { $0.xLabel == label })?.x
    }
}

/// The selection indicator: a hairline rule at the selected x with the tooltip.
public struct SelectionRuleMark: ChartContent {
    let input: ChartPlotInput

    public init(_ input: ChartPlotInput) {
        self.input = input
    }

    public var body: some ChartContent {
        if let x = XMarks.selectedX(input), let label = input.selection.wrappedValue {
            XMarks.rule(x, data: input.data)
                .foregroundStyle(input.theme.color.hairline)
                .lineStyle(StrokeStyle(lineWidth: 1))
                .annotation(
                    position: .top, spacing: 0,
                    overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))
                ) {
                    ChartTooltip(input, label: label)
                }
        }
    }
}
