// Owner: jr-1b (wave 1). Frozen after wave 1.
public import JSONRenderCore
public import SwiftUI

extension Catalog {
    /// Registers `C.definition` and a renderer that builds `C(context:)`. A name that
    /// already exists throws. Not main-actor isolated: a catalog can be built anywhere; the
    /// renderer closure runs on the main actor.
    public mutating func register<C: View & JRComponentType>(_ type: C.Type) throws(CatalogError) {
        let definition = C.definition
        try register(definition)
        renderers[definition.name] = ViewFactory { context in AnyView(C(context: context)) }
    }

    /// Replaces the renderer of an existing component and keeps its definition (a host
    /// override, layer e). Throws `unknownComponent` for a name the catalog does not define.
    public mutating func override(
        _ type: String, _ make: @escaping @MainActor @Sendable (JRRenderContext) -> AnyView
    ) throws(CatalogError) {
        guard component(named: type) != nil else { throw .unknownComponent(type) }
        renderers[type] = ViewFactory(make)
    }

    /// The renderer for a component type.
    public func viewFactory(for type: String) -> ViewFactory? {
        renderers[type] as? ViewFactory
    }
}
