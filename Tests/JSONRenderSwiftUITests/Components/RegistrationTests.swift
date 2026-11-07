import JSONRenderClient
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI
import Testing

@Suite struct RegistrationTests {
    @Test func standardCatalogHasRenderers() throws {
        let catalog = try Catalog.standard
        for name in StandardCatalogPromptTests.group1 {
            #expect(catalog.component(named: name) != nil, "no definition for \(name)")
            #expect(catalog.viewFactory(for: name) != nil, "no renderer for \(name)")
        }
    }
}
