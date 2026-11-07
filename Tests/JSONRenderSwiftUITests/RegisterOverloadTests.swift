import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

/// Regression: `catalog.register(MyView.self)` must pick the SwiftUI overload and keep the
/// renderer (wave-2 finding: the Core overload used to win and drop it).
@Suite("Register overload")
struct RegisterOverloadTests {
    struct Probe: View, JRComponentType {
        nonisolated static let definition = ComponentDefinition(name: "Probe")
        let context: JRRenderContext
        init(context: JRRenderContext) { self.context = context }
        var body: some View { Text("probe") }
    }

    @Test("A View component registers its renderer")
    func viewKeepsRenderer() throws {
        var catalog = Catalog()
        try catalog.register(Probe.self)
        #expect(catalog.component(named: "Probe") != nil)
        #expect(catalog.viewFactory(for: "Probe") != nil)
    }
}
