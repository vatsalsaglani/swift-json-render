internal import JSONRenderSwiftUI
public import SwiftUI

/// The rows of a chart as a table: the same values the marks show, formatted.
public struct ChartTableRow: Identifiable, Hashable, Sendable {
    public let id: Int
    public let x: String
    public let series: String
    public let value: String
}

extension ChartData {
    /// The table rows for "Show as Table".
    public func tableRows(locale: Locale = .current) -> [ChartTableRow] {
        points.map { point in
            ChartTableRow(
                id: point.id, x: point.xLabel,
                series: point.row ?? (point.series.isEmpty ? "" : point.series),
                value: text(point.y, locale: locale))
        }
    }

    /// `true` when the table needs a second column (series or heatmap rows).
    var tableHasSeries: Bool { hasSeries || !rows.isEmpty || kind == .combo }
}

/// "Show as Table": the chart's rows in a plain SwiftUI `Table` (a list on iOS). Local to
/// the charts module; it does not use the standard catalog.
struct ChartTableView: View {
    let data: ChartData
    let height: Double

    var body: some View {
        let rows = data.tableRows()
        #if os(macOS)
            Group {
                if data.tableHasSeries {
                    Table(rows) {
                        TableColumn(data.xField, value: \.x)
                        TableColumn(data.kind == .heatmap ? data.yField : "Series", value: \.series)
                        TableColumn("Value") { row in Text(row.value).monospacedDigit() }
                    }
                } else {
                    Table(rows) {
                        TableColumn(data.xField, value: \.x)
                        TableColumn("Value") { row in Text(row.value).monospacedDigit() }
                    }
                }
            }
            .frame(minHeight: height, maxHeight: max(height, 240))
        #else
            List(rows) { row in
                HStack {
                    Text(row.x)
                    if !row.series.isEmpty { Text(row.series).foregroundStyle(.secondary) }
                    Spacer()
                    Text(row.value).monospacedDigit()
                }
            }
            .frame(minHeight: height, maxHeight: max(height, 240))
        #endif
    }
}
