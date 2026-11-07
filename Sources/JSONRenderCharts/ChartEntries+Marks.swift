// Owner: jr-3c (wave 2); seeded empty by jr-1b. Append one line per chart.
internal import JSONRenderCore
internal import JSONRenderSwiftUI

extension ChartEntries {
    /// jr-3c's mark-based charts, in VPLAN §7.3 table order.
    static let marks: [ComponentDefinition] = [
        BarChart.definition,
        LineChart.definition,
        AreaChart.definition,
        PieChart.definition,
        JRGauge.definition,
        Sparkline.definition,
        ScatterChart.definition,
        Heatmap.definition,
        Histogram.definition,
        ComboChart.definition,
    ]

    /// Registers the mark charts, the four aggregation functions and the chart rule.
    static func registerMarks(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.registerChart(BarChart.self)
        try catalog.registerChart(LineChart.self)
        try catalog.registerChart(AreaChart.self)
        try catalog.registerChart(PieChart.self)
        try catalog.registerChart(JRGauge.self)
        try catalog.registerChart(Sparkline.self)
        try catalog.registerChart(ScatterChart.self)
        try catalog.registerChart(Heatmap.self)
        try catalog.registerChart(Histogram.self)
        try catalog.registerChart(ComboChart.self)
        ChartFunctions.register(into: &catalog)
        catalog.rule(ChartSpecRules.name, ChartSpecRules.check)
    }
}
