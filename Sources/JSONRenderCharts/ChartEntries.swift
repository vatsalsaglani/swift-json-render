// Owner: jr-1b (wave 1). Frozen: wave-2 agents append to their group files only.
public import JSONRenderCore
internal import JSONRenderSwiftUI

/// The chart component entries, summed from the group files.
public enum ChartEntries {
    /// Every chart definition, in registration order.
    public static var components: [ComponentDefinition] { marks + composite }

    /// Registers every chart component (definition and renderer).
    public static func register(into catalog: inout Catalog) throws(CatalogError) {
        try registerMarks(into: &catalog)
        try registerComposite(into: &catalog)
    }
}

extension Catalog {
    /// The chart catalog: the chart components and the built-in actions. Merge it with
    /// `Catalog.standard` through `merging(_:)`.
    public static var charts: Catalog {
        get throws(CatalogError) {
            var catalog = Catalog()
            try ChartEntries.register(into: &catalog)
            return catalog
        }
    }
}
