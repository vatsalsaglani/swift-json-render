import JSONRenderCore
import JSONRenderSwiftUI
import Testing

@testable import JSONRenderCharts

@Suite("Chart definitions and registration")
struct ChartDefinitionTests {
    /// jr-3c's charts, in VPLAN §7.3 table order.
    static let markNames = [
        "BarChart", "LineChart", "AreaChart", "PieChart", "Gauge", "Sparkline", "ScatterChart",
        "Heatmap", "Histogram", "ComboChart",
    ]

    @Test("The mark charts are registered in table order, with renderers")
    func registered() throws {
        let catalog = try Catalog.charts
        let names = ChartEntries.marks.map(\.name)
        #expect(names == Self.markNames)
        #expect(Array(catalog.componentNames.prefix(names.count)) == names)
        for name in names {
            #expect(catalog.viewFactory(for: name) != nil, "\(name) has no renderer")
        }
        #expect(catalog.ruleOrder.contains(ChartSpecRules.name))
    }

    @Test("Every definition has a description, an object schema and the chart slots")
    func shape() {
        for definition in ChartEntries.marks {
            #expect(!definition.description.isEmpty, "\(definition.name)")
            guard case .object(let fields) = definition.props.kind else {
                Issue.record("\(definition.name) props are not an object")
                continue
            }
            let names = fields.map(\.name)
            #expect(Set(names).count == names.count, "\(definition.name) repeats a prop")
            #expect(names.contains("summary"), "\(definition.name) has no summary prop")
            #expect(definition.slots.contains("title"), "\(definition.name)")
            #expect(!definition.props.formatted().isEmpty)
            #expect(!definition.acceptsChildren, "\(definition.name): a chart has no children")
        }
    }

    @Test("Each example validates against its own schema")
    func examples() throws {
        let catalog = try Catalog.charts
        for definition in ChartEntries.marks {
            let example = definition.example ?? [:]
            let spec = Spec(
                root: "c", elements: ["c": UIElement(type: definition.name, props: example)])
            let report = catalog.validate(spec)
            #expect(report.valid, "\(definition.name): \(report.issues.map(\.message))")
        }
    }

    @Test("The chart catalog merges with another catalog")
    func merges() throws {
        let merged = try Catalog().merging(try Catalog.charts)
        #expect(merged.component(named: "BarChart") != nil)
    }
}
