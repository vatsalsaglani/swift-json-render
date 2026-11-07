import Testing

@testable import JSONRenderCore

/// A Core-only component (no SwiftUI): proves the data side of the registry seam.
private struct Stat: JRComponentType {
    static let definition = ComponentDefinition(
        name: "Stat", description: "One number",
        props: .object([.init(name: "label", schema: .string)]))

    let label: String

    init(context: JRRenderContext) {
        label = context.prop("label")?.stringValue ?? ""
    }
}

@Suite("Registry seam (Core side)")
struct RegistrySeamTests {
    @Test("register(_ type:) adds the definition; a second register throws")
    func register() throws {
        var catalog = Catalog()
        try catalog.register(Stat.self)
        #expect(catalog.componentNames == ["Stat"])
        #expect(catalog.renderers.isEmpty)
        #expect(throws: CatalogError.duplicateComponent("Stat")) { try catalog.register(Stat.self) }
    }

    @MainActor
    @Test("JRRenderContext keeps undefined apart from null")
    func context() {
        let context = JRRenderContext(
            id: "s", props: ["label": "Revenue", "gone": Optional<JSONValue>.none, "null": .null])
        #expect(Stat(context: context).label == "Revenue")
        #expect(context.prop("gone") == nil)
        #expect(context.props["null"] == .some(.null))
        #expect(context.children.isEmpty)
    }
}
