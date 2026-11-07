public import Foundation
public import SwiftUI

/// The `AXChartDescriptor` for a chart, so VoiceOver audio graphs work. Categorical charts
/// (bars, pie, heatmap, treemap, funnel) use a categorical x axis of labels and a numeric
/// y axis of values; time and number axes use a numeric x axis.
public struct ChartAccessibilityDescriptor: AXChartDescriptorRepresentable {
    public let data: ChartData
    public let title: String
    public let summary: String

    public init(data: ChartData, title: String?, summary: String) {
        self.data = data
        self.title = title ?? data.kind.spokenName
        self.summary = summary
    }

    public func makeChartDescriptor() -> AXChartDescriptor {
        let format = data.format
        let unit = data.unit
        let xAxis: any AXDataAxisDescriptor
        switch data.xAxis {
        case .category:
            let order = data.categories.isEmpty ? data.points.map(\.xLabel) : data.categories
            xAxis = AXCategoricalDataAxisDescriptor(title: data.xField, categoryOrder: order)
        case .time:
            let values = data.points.compactMap(\.x.numeric)
            let low = values.min() ?? 0
            let high = Swift.max(values.max() ?? 1, low + 1)
            xAxis = AXNumericDataAxisDescriptor(
                title: data.xField, range: low...high, gridlinePositions: []
            ) { value in
                Date(timeIntervalSince1970: value).formatted(date: .abbreviated, time: .omitted)
            }
        case .number:
            let values = data.points.compactMap(\.x.numeric)
            let low = data.xDomain?.lowerBound ?? values.min() ?? 0
            let high = Swift.max(data.xDomain?.upperBound ?? values.max() ?? 1, low + 1)
            xAxis = AXNumericDataAxisDescriptor(
                title: data.xField, range: low...high, gridlinePositions: []
            ) { value in ChartValueFormat.number.axisString(value) }
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: data.yField, range: data.yDomain, gridlinePositions: []
        ) { value in format.string(value, unit: unit) }
        return AXChartDescriptor(
            title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [],
            series: series(continuous: data.kind == .line || data.kind == .area))
    }

    private func series(continuous: Bool) -> [AXDataSeriesDescriptor] {
        var groups: [String: [ChartPoint]] = [:]
        var order: [String] = []
        for point in data.points {
            let key = data.kind == .heatmap ? (point.row ?? "") : point.series
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(point)
        }
        return order.map { name in
            let points = (groups[name] ?? []).map { point -> AXDataPoint in
                let label = ChartAccessibilityDescriptor.label(point, data: data)
                switch data.xAxis {
                case .category:
                    return AXDataPoint(x: point.xLabel, y: point.y, label: label)
                case .time, .number:
                    return AXDataPoint(x: point.x.numeric ?? 0, y: point.y, label: label)
                }
            }
            return AXDataSeriesDescriptor(
                name: name.isEmpty ? data.yField : name, isContinuous: continuous,
                dataPoints: points)
        }
    }

    /// The spoken label of one mark: "run 4210, 70 s" or "Passed, run 4210, 1,210".
    public static func label(_ point: ChartPoint, data: ChartData, locale: Locale = .current)
        -> String
    {
        var parts: [String] = []
        if !point.series.isEmpty, data.hasSeries { parts.append(point.series) }
        if let row = point.row { parts.append(row) }
        switch data.xAxis {
        case .category where data.kind != .pie:
            parts.append("\(data.xField) \(point.xLabel)")
        default:
            parts.append(point.xLabel)
        }
        parts.append(data.text(point.y, locale: locale))
        return parts.joined(separator: ", ")
    }
}
