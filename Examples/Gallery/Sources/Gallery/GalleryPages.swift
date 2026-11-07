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
        FormFieldsPage.self, ButtonsPage.self, TablePage.self, MediaPage.self, FeedbackPage.self,
        // Charts (jr-3c, jr-3d)
        BarChartPage.self, LineChartPage.self, AreaChartPage.self, PieChartPage.self,
        GaugePage.self, SparklinePage.self, ScatterChartPage.self, HeatmapPage.self,
        HistogramPage.self, ComboChartPage.self, WaterfallPage.self, FunnelPage.self,
        BoxPlotPage.self, CandlestickPage.self, TreemapPage.self, StreamingSeriesPage.self,
        ShowAsTablePage.self,
        // Streaming (jr-2)
        StreamingReplayPage.self,
        // Theme (jr-3)
        ThemePresetsPage.self,
        // Accessibility (jr-3)
        AccessibilityPage.self,
    ]
}
