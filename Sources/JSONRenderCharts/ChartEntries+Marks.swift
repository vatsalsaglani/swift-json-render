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
        try catalog.register(BarChart.self)
        try catalog.register(LineChart.self)
        try catalog.register(AreaChart.self)
        try catalog.register(PieChart.self)
        try catalog.register(JRGauge.self)
        try catalog.register(Sparkline.self)
        try catalog.register(ScatterChart.self)
        try catalog.register(Heatmap.self)
        try catalog.register(Histogram.self)
        try catalog.register(ComboChart.self)
        ChartFunctions.register(into: &catalog)
        catalog.rule(ChartSpecRules.name, ChartSpecRules.check)
    }
}
