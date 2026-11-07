import JSONRenderClient
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI
import Testing

@Suite struct RegistrationTests {
    @Test func standardCatalogHasRenderers() throws {
        let catalog = try Catalog.standard
        #expect(catalog.componentNames.starts(with: ["Card", "Stack", "Text"]))
        for name in ["Card", "Stack", "Text"] {
            #expect(catalog.viewFactory(for: name) != nil, "no renderer for \(name)")
        }
    }
}

/// A host component, to prove which `register` overload stores a renderer.
@JRComponent("Probe", description: "A test component")
struct ProbeView: View {
    @JRProp var text: String
    var body: some View { Text(text) }
}

@Suite struct RegisterOverloadTests {
    /// Documents the overload trap: `register(X.self)` stores the definition only.
    @Test func unlabelledRegisterStoresNoRenderer() throws {
        var catalog = Catalog()
        try catalog.register(ProbeView.self)
        #expect(catalog.component(named: "Probe") != nil)
        #expect(catalog.viewFactory(for: "Probe") == nil)
    }

    @Test func registerViewStoresDefinitionAndRenderer() throws {
        var catalog = Catalog()
        try catalog.register(view: ProbeView.self)
        #expect(catalog.component(named: "Probe") == ProbeView.definition)
        #expect(catalog.viewFactory(for: "Probe") != nil)
        #expect(throws: CatalogError.duplicateComponent("Probe")) {
            try catalog.register(view: ProbeView.self)
        }
    }
}
