/// The chart budgets of VPLAN §7.3.
public enum ChartBudgets {
    /// Points per chart; more is a validator error and a render-time message.
    public static let maxPoints = 5_000
    /// Line and area charts above this are downsampled (LTTB) to it.
    public static let downsampleThreshold = 1_000
    /// Series per chart; more is an error.
    public static let maxSeries = 12
    /// After this many series the palette cycles with a dash pattern.
    public static let paletteSize = 8
    /// Pie slices shown before "Other".
    public static let defaultPieSlices = 6
    /// Pie slices accepted; more is an error that suggests BarChart.
    public static let maxPieSlices = 12
    /// Heatmap cells; more is an error.
    public static let maxHeatmapCells = 2_500
    /// LineChart `points: auto` shows points up to this many per series.
    public static let autoPointLimit = 30
    /// Histogram bins accepted.
    public static let maxBins = 100
}
