import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import Testing

/// Each standard component's prompt line equals upstream's once the Swift extras (the "+"
/// props, extra slots and extra enum values) are removed.
@Suite struct StandardCatalogPromptTests {
    /// Swift additions per component: props, slots, enum values per prop.
    static let extras: [String: (props: [String], slots: [String], values: [String: [String]])] = [
        "Card": (["variant"], ["header", "footer"], [:]),
        "Stack": (["wrap"], [], [:]),
        "Tabs": (["variant"], [], [:]),
        "Collapsible": (["open"], [], [:]),
        "Dialog": (["open"], ["footer"], [:]),
        "Drawer": (["open"], ["footer"], [:]),
        "Badge": ([], [], ["variant": ["good", "warning", "critical"]]),
        "Skeleton": (["shape"], [], [:]),
        // Group 2 (jr-3b).
        "Image": (["fit"], ["error", "loading"], [:]),
        "Carousel": ([], ["default"], [:]),
        "Table": (["sortable"], ["default", "empty", "loading"], [:]),
        "Button": (["size", "icon"], [], ["variant": ["destructive", "plain"]]),
    ]

    static let group1 = [
        "Card", "Stack", "Grid", "Separator", "Tabs", "Accordion", "Collapsible", "Pagination",
        "Dialog", "Drawer", "Tooltip", "Popover", "DropdownMenu", "Heading", "Text", "Badge",
        "Alert", "Skeleton",
    ]

    static func upstreamLines() throws -> [String: String] {
        let text = try Fixtures.text("prompt/shadcn-standalone.txt")
        var lines: [String: String] = [:]
        for line in text.split(separator: "\n") where line.hasPrefix("- ") {
            guard let colon = line.firstIndex(of: ":") else { continue }
            let name = String(line[line.index(line.startIndex, offsetBy: 2)..<colon])
            if name.allSatisfy({ $0.isLetter }) { lines[name] = String(line) }
        }
        return lines
    }

    static func stripped(_ definition: ComponentDefinition) -> ComponentDefinition {
        guard let extra = extras[definition.name], case .object(let fields) = definition.props.kind
        else { return definition }
        var copy = definition
        copy.slots.removeAll { extra.slots.contains($0) }
        copy.props.kind = .object(
            fields.filter { !extra.props.contains($0.name) }.map { field in
                guard let drop = extra.values[field.name],
                    case .enum(let values) = field.schema.kind
                else { return field }
                var schema = field.schema
                schema.kind = .enum(values.filter { !drop.contains($0) })
                return PropSchema.Field(
                    name: field.name, schema: schema, description: field.description)
            })
        return copy
    }

    @Test func group1IsRegisteredInTableOrder() throws {
        let names = try Catalog.standard.componentNames
        #expect(Array(names.prefix(18)) == Self.group1)
        #expect(StandardEntries.components.prefix(18).map(\.name) == Self.group1)
    }

    @Test(arguments: StandardCatalogPromptTests.group1)
    func promptLineMatchesUpstream(_ name: String) throws {
        let catalog = try Catalog.standard
        let definition = try #require(catalog.component(named: name))
        let expected = try #require(try Self.upstreamLines()[name])
        let single = Catalog(components: [Self.stripped(definition)])
        let line = single.prompt().split(separator: "\n").first { $0.hasPrefix("- \(name):") }
        #expect(line.map(String.init) == expected)
    }

    @Test func definitionsInTheListMatchTheRegisteredOnes() throws {
        let catalog = try Catalog.standard
        for definition in StandardEntries.components {
            #expect(catalog.component(named: definition.name) == definition)
            #expect(catalog.viewFactory(for: definition.name) != nil, "\(definition.name)")
        }
    }
}
