// Owner: jr-3 (Gallery shell). Other agents hand their lines to the coordinator.

/// Every page, in sidebar order within each group.
@MainActor
enum GalleryPages {
    static let all: [any GalleryPage.Type] = [
        // Components (jr-3)
        CardPage.self,
        StackPage.self,
        GridPage.self,
        TextPage.self,
        TabsPage.self,
        DisclosurePage.self,
        OverlaysPage.self,
        StatusPage.self,
        FixtureSpecsPage.self,
        // Inputs (jr-3b)
        // Charts (jr-3c, jr-3d)
        // Streaming (jr-2)
        // Theme (jr-3)
        ThemePresetsPage.self,
        // Accessibility (jr-3)
    ]
}
