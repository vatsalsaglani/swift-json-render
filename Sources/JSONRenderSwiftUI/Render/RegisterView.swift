// Owner: jr-3 (wave 2). The reachable form of `Registry/Catalog+Register.swift`'s
// `register<C: View & JRComponentType>(_:)`.
public import JSONRenderCore
public import SwiftUI

extension Catalog {
    /// Registers a SwiftUI component: `C.definition` and a renderer that builds
    /// `C(context:)`. A name that already exists throws.
    ///
    /// Use this, not `register(MyView.self)`. For a concrete type (and inside a generic
    /// function) Swift resolves `register(_:)` to Core's non-generic
    /// `register(_: any JRComponentType.Type)`, which stores the definition only, so the
    /// element would draw a fallback block. The `view:` label removes the ambiguity.
    public mutating func register<C: View & JRComponentType>(view type: C.Type)
        throws(CatalogError)
    {
        let definition = C.definition
        try register(definition)
        renderers[definition.name] = ViewFactory { context in AnyView(C(context: context)) }
    }
}
