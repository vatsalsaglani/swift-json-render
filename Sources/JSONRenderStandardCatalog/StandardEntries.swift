// Owner: jr-1b (wave 1). Frozen: wave-2 agents append to their group files only.
public import JSONRenderCore
internal import JSONRenderSwiftUI

/// The standard component entries, summed from the group files.
public enum StandardEntries {
    /// Every standard definition, in registration order.
    public static var components: [ComponentDefinition] { group1 + group2 }

    /// Registers every standard component (definition and renderer).
    public static func register(into catalog: inout Catalog) throws(CatalogError) {
        try registerGroup1(into: &catalog)
        try registerGroup2(into: &catalog)
    }
}

extension Catalog {
    /// The standard catalog: the standard components and the built-in actions.
    public static var standard: Catalog {
        get throws(CatalogError) {
            var catalog = Catalog()
            try StandardEntries.register(into: &catalog)
            return catalog
        }
    }
}
