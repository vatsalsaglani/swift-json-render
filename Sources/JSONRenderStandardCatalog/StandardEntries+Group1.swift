// Owner: jr-3 (wave 2); seeded empty by jr-1b. Append one line per component.
internal import JSONRenderCore
internal import JSONRenderSwiftUI

extension StandardEntries {
    /// jr-3's 18 components, in prompt order.
    static let group1: [ComponentDefinition] = [
        JRCard.definition,
        JRStack.definition,
        JRText.definition,
    ]

    static func registerGroup1(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.register(view: JRCard.self)
        try catalog.register(view: JRStack.self)
        try catalog.register(view: JRText.self)
    }
}
