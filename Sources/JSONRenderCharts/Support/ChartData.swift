public import Foundation

/// An x value: a category, a date (time axis) or a number.
public enum ChartXValue: Sendable, Hashable {
    case category(String)
    case date(Date)
    case number(Double)

    /// A number for ordering and downsampling (a category has none).
    var numeric: Double? {
        switch self {
        case .category: nil
        case .date(let date): date.timeIntervalSince1970
        case .number(let value): value
        }
    }
}

/// What the x axis shows.
public enum ChartAxisKind: Sendable, Hashable {
    case category, time, number
}

/// One drawable value. Charts draw points; they never read the raw rows.
public struct ChartPoint: Sendable, Hashable, Identifiable {
    /// The position in `ChartData.points`.
    public var id: Int
    public var x: ChartXValue
    /// The x as text: the raw category, the raw date string, or the formatted number. The
    /// selection writes this value back (or the number, for a numeric axis).
    public var xLabel: String
    /// The end of a range on x (histogram bins).
    public var xEnd: Double?
    public var y: Double
    /// The series name; `""` when the chart has one series.
    public var series: String
    /// The row category (heatmap).
    public var row: String?
    /// The bubble size (scatter).
    public var size: Double?
    /// `true` for the folded "Other" value.
    public var isOther: Bool
    /// The stack baseline (stacked and 100 % bars): the mark spans `base...base + y`.
    public var base: Double?

    public init(
        id: Int, x: ChartXValue, xLabel: String, xEnd: Double? = nil, y: Double,
        series: String = "", row: String? = nil, size: Double? = nil, isOther: Bool = false,
        base: Double? = nil
    ) {
        self.id = id
        self.x = x
        self.xLabel = xLabel
        self.xEnd = xEnd
        self.y = y
        self.series = series
        self.row = row
        self.size = size
        self.isOther = isOther
        self.base = base
    }
}

/// A note from `ChartData.make`. Blocking notes replace the chart with a message (the
/// validator reports the same rules as errors for literal data).
public enum ChartWarning: Sendable, Hashable {
    /// Rows without a usable x or a numeric y were skipped.
    case skippedRows(Int)
    /// Some x values parse as dates and some do not; the axis is categorical.
    case mixedTimeAxis
    /// A line or area series was downsampled (LTTB).
    case downsampled(from: Int, to: Int)
    /// Values beyond a limit were folded into "Other".
    case foldedIntoOther(Int)
    /// The `format` prop is not a known format; numbers print plainly.
    case unknownFormat
    /// A pie with one slice renders as a single value.
    case singleSlice
    /// Blocking: more than 5,000 points.
    case tooManyPoints(Int)
    /// Blocking: more than 12 series.
    case tooManySeries(Int)
    /// Blocking: more than 12 pie slices.
    case tooManySlices(Int)
    /// Blocking: a pie value is negative.
    case negativeSlice
    /// Blocking: more than 2,500 heatmap cells.
    case tooManyCells(Int)

    /// `true` when the chart shows a message instead of marks.
    public var isBlocking: Bool {
        switch self {
        case .tooManyPoints, .tooManySeries, .tooManySlices, .negativeSlice, .tooManyCells:
            true
        default:
            false
        }
    }

    /// The rule text (no data values).
    public var message: String {
        switch self {
        case .skippedRows(let count): "\(count) rows were skipped (missing x or non-numeric value)."
        case .mixedTimeAxis: "Some x values are not dates; the axis shows them as categories."
        case .downsampled(let from, let to): "\(from) points are drawn as \(to)."
        case .foldedIntoOther(let count): "\(count) values are grouped into Other."
        case .unknownFormat: "The format is not known; numbers print plainly."
        case .singleSlice: "A pie with one slice shows as a single value. Use Gauge or Stat."
        case .tooManyPoints(let count):
            "This chart has \(count) points; the limit is \(ChartBudgets.maxPoints)."
        case .tooManySeries(let count):
            "This chart has \(count) series; the limit is \(ChartBudgets.maxSeries)."
        case .tooManySlices(let count):
            "This pie has \(count) slices; the limit is \(ChartBudgets.maxPieSlices). Use BarChart."
        case .negativeSlice: "A pie cannot show negative values. Use BarChart."
        case .tooManyCells(let count):
            "This heatmap has \(count) cells; the limit is \(ChartBudgets.maxHeatmapCells)."
        }
    }
}

/// The resolved, drawable form of a chart's props. Built once per data change by
/// `ChartData.make(props:kind:)` (a pure function), never in a view body.
public struct ChartData: Sendable, Hashable {
    public var kind: ChartKind
    public var points: [ChartPoint]
    public var xAxis: ChartAxisKind
    /// x categories in display order (category axes).
    public var categories: [String]
    /// Row categories in display order (heatmap).
    public var rows: [String]
    /// Series in order of first appearance; empty for a one-series chart.
    public var series: [String]
    /// The field names that produced x and y (for labels and the summary).
    public var xField: String
    public var yField: String
    public var format: ChartValueFormat
    /// The format the y axis uses (`percent` for 100 % layouts).
    public var axisFormat: ChartValueFormat
    public var unit: String?
    /// The extent of the drawn values (stacked totals for stacked layouts), or `nil`.
    public var dataRange: ClosedRange<Double>?
    /// The y domain to draw: the `yDomain` prop, or nice numbers around `dataRange`.
    public var yDomain: ClosedRange<Double>
    /// `true` when `yDomain` came from the spec (streaming then never changes it).
    public var yDomainIsFixed: Bool
    /// The x domain for a numeric axis.
    public var xDomain: ClosedRange<Double>?
    public var referenceLines: [ChartReferenceLine]
    /// The first blocking note, if any.
    public var blocking: ChartWarning?
    /// Chart-specific options decoded with the data.
    public var options: ChartOptions

    /// `true` when there is nothing to draw.
    public var isEmpty: Bool { points.isEmpty }

    /// `true` when series colours (and a legend) apply.
    public var hasSeries: Bool { series.count > 1 }

    /// The display text for a value in this chart's format and unit.
    public func text(_ value: Double, locale: Locale = .current) -> String {
        format.string(value, unit: unit, locale: locale)
    }

    public init(
        kind: ChartKind, points: [ChartPoint] = [], xAxis: ChartAxisKind = .category,
        categories: [String] = [], rows: [String] = [], series: [String] = [],
        xField: String = "x", yField: String = "y", format: ChartValueFormat = .number,
        axisFormat: ChartValueFormat? = nil, unit: String? = nil,
        dataRange: ClosedRange<Double>? = nil, yDomain: ClosedRange<Double> = 0...1,
        yDomainIsFixed: Bool = false, xDomain: ClosedRange<Double>? = nil,
        referenceLines: [ChartReferenceLine] = [], blocking: ChartWarning? = nil,
        options: ChartOptions = ChartOptions()
    ) {
        self.kind = kind
        self.points = points
        self.xAxis = xAxis
        self.categories = categories
        self.rows = rows
        self.series = series
        self.xField = xField
        self.yField = yField
        self.format = format
        self.axisFormat = axisFormat ?? format
        self.unit = unit
        self.dataRange = dataRange
        self.yDomain = yDomain
        self.yDomainIsFixed = yDomainIsFixed
        self.xDomain = xDomain
        self.referenceLines = referenceLines
        self.blocking = blocking
        self.options = options
    }
}

/// Per-chart options, decoded once with the data.
public struct ChartOptions: Sendable, Hashable {
    public enum Orientation: String, Sendable, Hashable, CaseIterable { case vertical, horizontal }
    public enum BarLayout: String, Sendable, Hashable, CaseIterable {
        case grouped, stacked, normalized
    }
    public enum AreaLayout: String, Sendable, Hashable, CaseIterable {
        case overlap, stacked, normalized
    }
    public enum Sort: String, Sendable, Hashable, CaseIterable { case none, asc, desc }
    public enum Curve: String, Sendable, Hashable, CaseIterable { case linear, monotone, step }
    public enum Points: String, Sendable, Hashable, CaseIterable { case auto, always, never }
    public enum Emphasis: String, Sendable, Hashable, CaseIterable { case last, max, none }
    public enum Trend: String, Sendable, Hashable, CaseIterable { case none, linear }
    public enum HeatScale: String, Sendable, Hashable, CaseIterable {
        case sequential, diverging
    }
    public enum HeatLayout: String, Sendable, Hashable, CaseIterable { case grid, calendar }
    public enum HistogramMode: String, Sendable, Hashable, CaseIterable { case count, percent }

    public var orientation: Orientation = .vertical
    public var barLayout: BarLayout = .grouped
    public var areaLayout: AreaLayout = .overlap
    public var sort: Sort = .none
    public var limit: Int?
    public var curve: Curve = .linear
    public var points: Points = .auto
    public var donut = false
    public var maxSlices = 6
    public var emphasis: Emphasis = .last
    public var filled = false
    public var intent: ChartIntent?
    public var trend: Trend = .none
    /// The linear fit `y = slope · x + intercept` (scatter with `trend: linear`).
    public var fit: LinearFit?
    public var heatScale: HeatScale = .sequential
    public var heatLayout: HeatLayout = .grid
    /// The value range of heatmap cells.
    public var valueRange: ClosedRange<Double>?
    public var histogramMode: HistogramMode = .count
    /// The format and unit of the x values (histogram bins); y then shows counts.
    public var xFormat: ChartValueFormat = .number
    public var xUnit: String?
    /// The field drawn as a line (combo).
    public var lineField: String?
    /// The size range of bubbles (scatter).
    public var sizeRange: ClosedRange<Double>?

    public init() {}
}

/// A least-squares line.
public struct LinearFit: Sendable, Hashable {
    public var slope: Double
    public var intercept: Double

    public func y(at x: Double) -> Double { slope * x + intercept }

    /// The fit for the points, or `nil` for fewer than two distinct x values.
    public static func leastSquares(x: [Double], y: [Double]) -> LinearFit? {
        let count = Double(Swift.min(x.count, y.count))
        guard count >= 2 else { return nil }
        let meanX = x.reduce(0, +) / count
        let meanY = y.reduce(0, +) / count
        var numerator = 0.0
        var denominator = 0.0
        for (px, py) in zip(x, y) {
            numerator += (px - meanX) * (py - meanY)
            denominator += (px - meanX) * (px - meanX)
        }
        guard denominator > 0 else { return nil }
        let slope = numerator / denominator
        return LinearFit(slope: slope, intercept: meanY - slope * meanX)
    }
}
