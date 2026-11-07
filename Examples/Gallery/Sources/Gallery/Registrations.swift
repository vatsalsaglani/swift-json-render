// Owner: the coordinator. `GalleryPage` conformances for pages that agents wrote before the
// Gallery shell landed (jr-2 streaming, jr-3c charts).

extension StreamingReplayPage: GalleryPage { static var group: GalleryGroup { .streaming } }

extension BarChartPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension LineChartPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension AreaChartPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension PieChartPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension GaugePage: GalleryPage { static var group: GalleryGroup { .charts } }
extension SparklinePage: GalleryPage { static var group: GalleryGroup { .charts } }
extension ScatterChartPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension HeatmapPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension HistogramPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension ComboChartPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension StreamingSeriesPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension ShowAsTablePage: GalleryPage { static var group: GalleryGroup { .charts } }

extension WaterfallPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension FunnelPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension BoxPlotPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension CandlestickPage: GalleryPage { static var group: GalleryGroup { .charts } }
extension TreemapPage: GalleryPage { static var group: GalleryGroup { .charts } }
