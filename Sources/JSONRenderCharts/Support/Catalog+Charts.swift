public import JSONRenderCore
internal import JSONRenderSwiftUI
public import SwiftUI

extension Catalog {
    /// Registers a chart's definition and its renderer.
    ///
    /// `catalog.register(BarChart.self)` resolves to Core's non-generic
    /// `register(_: any JRComponentType.Type)`, which adds the definition only: Swift prefers
    /// the non-generic overload over `JSONRenderSwiftUI`'s generic
    /// `register<C: View & JRComponentType>`. This helper sets the renderer explicitly.
    public mutating func registerChart<C: View & JRComponentType>(_ type: C.Type)
        throws(CatalogError)
    {
        let definition = C.definition
        try register(definition)
        renderers[definition.name] = ViewFactory { context in AnyView(C(context: context)) }
    }
}
