// Owner: jr-3c (wave 2); seeded empty by jr-1b. Append one line per chart.
internal import JSONRenderCore
internal import JSONRenderSwiftUI

extension ChartEntries {
    /// jr-3c's mark-based charts, in VPLAN §7.3 table order.
    static let marks: [ComponentDefinition] = [
        BarChart.definition
    ]

    static func registerMarks(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.registerChart(BarChart.self)
        ChartFunctions.register(into: &catalog)
        catalog.rule(ChartSpecRules.name, ChartSpecRules.check)
    }
}
