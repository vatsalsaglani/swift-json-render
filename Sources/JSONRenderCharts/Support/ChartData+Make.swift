internal import Foundation
public import JSONRenderCore
internal import os

extension ChartData {
    /// Decodes resolved props into drawable data. Pure and `Sendable`: it parses dates,
    /// aggregates, sorts, folds into "Other", downsamples and computes nice domains once.
    /// Rows with a missing x or a non-numeric y are skipped and counted.
    public static func make(props: [String: JSONValue?], kind: ChartKind)
        -> (ChartData, [ChartWarning])
    {
        var builder = ChartDataBuilder(props: props, kind: kind)
        return builder.build()
    }
}

/// Collects one chart's data and warnings.
struct ChartDataBuilder {
    let reader: ChartPropReader
    let kind: ChartKind
    var warnings: [ChartWarning] = []
    var data: ChartData

    init(props: [String: JSONValue?], kind: ChartKind) {
        self.reader = ChartPropReader(props)
        self.kind = kind
        self.data = ChartData(kind: kind)
    }

    /// One usable row.
    struct Entry {
        var rawX: JSONValue
        var xText: String
        var y: Double
        var series: String
        var row: String?
        var size: Double?
    }

    mutating func build() -> (ChartData, [ChartWarning]) {
        if let raw = reader.string("format") {
            if let format = ChartValueFormat(raw) {
                data.format = format
            } else {
                warnings.append(.unknownFormat)
            }
        }
        data.axisFormat = data.format
        data.unit = reader.string("unit")
        data.referenceLines = reader.referenceLines
        switch kind {
        case .bar: buildBar()
        case .line, .area: buildLineOrArea()
        case .pie: buildPie()
        case .scatter: buildScatter()
        case .heatmap: buildHeatmap()
        case .histogram: buildHistogram()
        case .sparkline: buildSparkline()
        case .combo: buildCombo()
        default: buildLineOrArea()
        }
        finishDomain()
        data.blocking = warnings.first(where: \.isBlocking)
        return (data, warnings)
    }

    // MARK: - Shared

    var rows: [JSONValue] { reader.array("data") ?? [] }

    /// Extracts rows with `x` and a numeric `y`. Skipped rows are counted once.
    mutating func entries(
        x xField: String, y yField: String, series seriesField: String? = nil,
        row rowField: String? = nil, size sizeField: String? = nil
    ) -> [Entry] {
        var result: [Entry] = []
        var skipped = 0
        for row in rows {
            guard case .object(let fields) = row,
                let rawX = fields[xField], rawX != .null, let xText = ChartValues.text(rawX),
                let y = ChartValues.number(fields[yField])
            else {
                skipped += 1
                continue
            }
            var rowName: String?
            if let rowField {
                guard let text = ChartValues.text(fields[rowField]) else {
                    skipped += 1
                    continue
                }
                rowName = text
            }
            result.append(
                Entry(
                    rawX: rawX, xText: xText, y: y,
                    series: seriesField.flatMap { ChartValues.text(fields[$0]) } ?? "",
                    row: rowName, size: sizeField.flatMap { ChartValues.number(fields[$0]) }))
        }
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        if result.count > ChartBudgets.maxPoints {
            warnings.append(.tooManyPoints(result.count))
        }
        return result
    }

    /// Series names in first-appearance order; empty for one unnamed series.
    mutating func seriesOrder(_ entries: [Entry]) -> [String] {
        var seen = Set<String>()
        var order: [String] = []
        for entry in entries where seen.insert(entry.series).inserted {
            order.append(entry.series)
        }
        if order == [""] { return [] }
        if order.count > ChartBudgets.maxSeries { warnings.append(.tooManySeries(order.count)) }
        return order
    }

    /// The x axis kind for these entries, and the parsed dates when it is a time axis.
    mutating func axis(for entries: [Entry], allowNumber: Bool) -> (ChartAxisKind, [Date?]) {
        guard !entries.isEmpty else { return (.category, []) }
        let dates = entries.map { ChartDates.parse($0.xText) }
        let parsed = dates.filter { $0 != nil }.count
        if parsed == entries.count { return (.time, dates) }
        if parsed > 0 { warnings.append(.mixedTimeAxis) }
        if allowNumber, parsed == 0,
            entries.allSatisfy({ if case .number = $0.rawX { true } else { false } })
        {
            return (.number, dates)
        }
        return (.category, dates)
    }

    /// Categories in first-appearance order, or by date on a time axis.
    func categoryOrder(_ entries: [Entry], dates: [Date?]) -> [String] {
        var seen = Set<String>()
        var order: [(String, Date?)] = []
        for (index, entry) in entries.enumerated() where seen.insert(entry.xText).inserted {
            order.append((entry.xText, dates.indices.contains(index) ? dates[index] : nil))
        }
        if order.allSatisfy({ $0.1 != nil }) {
            order.sort { ($0.1 ?? .distantPast) < ($1.1 ?? .distantPast) }
        }
        return order.map(\.0)
    }

    mutating func finishDomain() {
        var range = data.dataRange
        for line in data.referenceLines {
            range =
                range.map { min($0.lowerBound, line.value)...max($0.upperBound, line.value) }
                ?? line.value...line.value
        }
        if let fixed = reader.range("yDomain") {
            data.yDomain = fixed
            data.yDomainIsFixed = true
        } else if let range {
            data.yDomain = NiceScale.domain(range, includeZero: includesZero)
        } else {
            data.yDomain = 0...1
        }
    }

    /// Bars and areas start at zero. Lines too (the axis then needs no note); scatter and
    /// sparkline fit the data.
    var includesZero: Bool {
        switch kind {
        case .scatter, .sparkline: false
        default: true
        }
    }

    static func extent(_ values: [Double]) -> ClosedRange<Double>? {
        guard let low = values.min(), let high = values.max() else { return nil }
        return low...high
    }

    // MARK: - BarChart

    mutating func buildBar() {
        let xField = reader.string("x") ?? "x"
        let yField = reader.string("y") ?? "y"
        data.xField = xField
        data.yField = yField
        var options = ChartOptions()
        options.orientation = reader.choice("orientation", default: .vertical)
        options.barLayout = reader.choice("layout", default: .grouped)
        options.sort = reader.choice("sort", default: .none)
        options.limit = reader.number("limit").map { max(1, Int($0.rounded())) }
        let entries = entries(x: xField, y: yField, series: reader.string("series"))
        let series = seriesOrder(entries)
        let (_, dates) = axis(for: entries, allowNumber: false)
        var categories = categoryOrder(entries, dates: dates)
        let seriesKeys = series.isEmpty ? [""] : series
        var sums: [String: [String: Double]] = [:]
        for entry in entries {
            sums[entry.xText, default: [:]][entry.series, default: 0] += entry.y
        }
        func total(_ category: String) -> Double { sums[category]?.values.reduce(0, +) ?? 0 }
        switch options.sort {
        case .none: break
        case .asc: categories = stableSorted(categories) { total($0) < total($1) }
        case .desc: categories = stableSorted(categories) { total($0) > total($1) }
        }
        var otherName: String?
        if let limit = options.limit, categories.count > limit {
            let rest = Array(categories.dropFirst(limit))
            categories = Array(categories.prefix(limit))
            let name = "Other (\(rest.count))"
            var folded: [String: Double] = [:]
            for category in rest {
                for (key, value) in sums[category] ?? [:] { folded[key, default: 0] += value }
            }
            sums[name] = folded
            categories.append(name)
            otherName = name
            warnings.append(.foldedIntoOther(rest.count))
        }
        var points: [ChartPoint] = []
        var low = 0.0
        var high = 0.0
        for category in categories {
            let values = sums[category] ?? [:]
            let magnitude = seriesKeys.reduce(0) { $0 + abs(values[$1] ?? 0) }
            if options.barLayout == .normalized, magnitude == 0 { continue }
            var positive = 0.0
            var negative = 0.0
            for key in seriesKeys {
                guard var value = values[key] else { continue }
                if options.barLayout == .normalized { value = value / magnitude * 100 }
                let base: Double? =
                    options.barLayout == .grouped ? nil : (value >= 0 ? positive : negative)
                points.append(
                    ChartPoint(
                        id: points.count, x: .category(category), xLabel: category, y: value,
                        series: key, isOther: category == otherName, base: base))
                if value >= 0 { positive += value } else { negative += value }
                if options.barLayout == .grouped {
                    low = min(low, value)
                    high = max(high, value)
                }
            }
            if options.barLayout != .grouped {
                low = min(low, negative)
                high = max(high, positive)
            }
        }
        data.points = points
        data.categories = categories.filter { name in points.contains { $0.xLabel == name } }
        data.series = series
        data.xAxis = .category
        data.options = options
        if options.barLayout == .normalized {
            data.axisFormat = .percent
            data.dataRange = points.isEmpty ? nil : min(low, 0)...100
        } else {
            data.dataRange = points.isEmpty ? nil : low...high
        }
    }

    func stableSorted(_ items: [String], by less: (String, String) -> Bool) -> [String] {
        items.enumerated().sorted { lhs, rhs in
            if less(lhs.element, rhs.element) { return true }
            if less(rhs.element, lhs.element) { return false }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    // MARK: - LineChart and AreaChart

    mutating func buildLineOrArea() {
        let xField = reader.string("x") ?? "x"
        let yField = reader.string("y") ?? "y"
        data.xField = xField
        data.yField = yField
        var options = ChartOptions()
        options.curve = reader.choice("curve", default: .linear)
        options.points = reader.choice("points", default: .auto)
        options.areaLayout = reader.choice("layout", default: .overlap)
        let entries = entries(x: xField, y: yField, series: reader.string("series"))
        let series = seriesOrder(entries)
        let (axisKind, dates) = axis(for: entries, allowNumber: true)
        let categories = axisKind == .category ? categoryOrder(entries, dates: dates) : []
        let categoryIndex = Dictionary(
            categories.enumerated().map { ($1, Double($0)) },
            uniquingKeysWith: { first, _ in first })
        struct Raw {
            var x: ChartXValue
            var label: String
            var order: Double
            var y: Double
            var series: String
        }
        var raws: [Raw] = entries.enumerated().map { index, entry in
            switch axisKind {
            case .time:
                let date = dates[index] ?? .distantPast
                return Raw(
                    x: .date(date), label: entry.xText, order: date.timeIntervalSince1970,
                    y: entry.y, series: entry.series)
            case .number:
                let value = entry.rawX.numberValue ?? 0
                return Raw(
                    x: .number(value), label: entry.xText, order: value, y: entry.y,
                    series: entry.series)
            case .category:
                return Raw(
                    x: .category(entry.xText), label: entry.xText,
                    order: categoryIndex[entry.xText] ?? 0, y: entry.y, series: entry.series)
            }
        }
        // Out-of-order points on a time or number axis are sorted (stable).
        raws = raws.enumerated().sorted { lhs, rhs in
            lhs.element.order != rhs.element.order
                ? lhs.element.order < rhs.element.order : lhs.offset < rhs.offset
        }.map(\.element)
        let isArea = kind == .area
        if isArea {
            // Areas stack per x: sum duplicates of (x, series).
            var merged: [Raw] = []
            var index: [String: Int] = [:]
            for raw in raws {
                let key = raw.label + "\u{1F}" + raw.series
                if let at = index[key] {
                    merged[at].y += raw.y
                } else {
                    index[key] = merged.count
                    merged.append(raw)
                }
            }
            raws = merged
        }
        // Downsample long series (LTTB), per series, to the shared budget.
        if raws.count > ChartBudgets.downsampleThreshold, !isArea || options.areaLayout == .overlap
        {
            let keys = series.isEmpty ? [""] : series
            let budget = max(3, ChartBudgets.downsampleThreshold / keys.count)
            var kept: [Raw] = []
            for key in keys {
                let line = raws.filter { $0.series == key }
                kept += LTTB.downsample(line, threshold: budget, x: \.order, y: \.y)
            }
            warnings.append(.downsampled(from: raws.count, to: kept.count))
            raws = kept.enumerated().sorted { lhs, rhs in
                lhs.element.order != rhs.element.order
                    ? lhs.element.order < rhs.element.order : lhs.offset < rhs.offset
            }.map(\.element)
        }
        var values: [Double] = []
        if isArea, options.areaLayout != .overlap {
            var totals: [String: Double] = [:]
            var magnitudes: [String: Double] = [:]
            for raw in raws {
                totals[raw.label, default: 0] += raw.y
                magnitudes[raw.label, default: 0] += abs(raw.y)
            }
            if options.areaLayout == .normalized {
                raws = raws.compactMap { raw in
                    guard let magnitude = magnitudes[raw.label], magnitude > 0 else { return nil }
                    var copy = raw
                    copy.y = raw.y / magnitude * 100
                    return copy
                }
                values = raws.isEmpty ? [] : [0, 100]
                data.axisFormat = .percent
            } else {
                values = Array(totals.values) + [0]
            }
        } else {
            values = raws.map(\.y)
        }
        data.points = raws.enumerated().map { index, raw in
            ChartPoint(id: index, x: raw.x, xLabel: raw.label, y: raw.y, series: raw.series)
        }
        data.series = series
        data.categories = categories
        data.xAxis = axisKind
        data.options = options
        data.dataRange = Self.extent(values)
        if axisKind == .number, let range = Self.extent(raws.map(\.order)) {
            data.xDomain = reader.range("xDomain") ?? range
        }
    }

    // MARK: - PieChart

    mutating func buildPie() {
        let labelField = reader.string("label") ?? "label"
        let valueField = reader.string("value") ?? "value"
        data.xField = labelField
        data.yField = valueField
        var options = ChartOptions()
        options.donut = reader.bool("donut") ?? false
        options.maxSlices = min(
            max(reader.number("maxSlices").map { Int($0.rounded()) } ?? 6, 2),
            ChartBudgets.maxPieSlices)
        let entries = entries(x: labelField, y: valueField)
        if entries.contains(where: { $0.y < 0 }) { warnings.append(.negativeSlice) }
        var order: [String] = []
        var sums: [String: Double] = [:]
        for entry in entries {
            if sums[entry.xText] == nil { order.append(entry.xText) }
            sums[entry.xText, default: 0] += max(entry.y, 0)
        }
        if order.count > ChartBudgets.maxPieSlices {
            warnings.append(.tooManySlices(order.count))
        }
        if order.count == 1 { warnings.append(.singleSlice) }
        var slices = stableSorted(order) { (sums[$0] ?? 0) > (sums[$1] ?? 0) }
        var otherValue: Double?
        if slices.count > options.maxSlices {
            let keep = options.maxSlices - 1
            let rest = slices.dropFirst(keep)
            otherValue = rest.reduce(0) { $0 + (sums[$1] ?? 0) }
            warnings.append(.foldedIntoOther(rest.count))
            slices = Array(slices.prefix(keep))
        }
        var points = slices.enumerated().map { index, name in
            ChartPoint(id: index, x: .category(name), xLabel: name, y: sums[name] ?? 0)
        }
        if let otherValue {
            points.append(
                ChartPoint(
                    id: points.count, x: .category("Other"), xLabel: "Other", y: otherValue,
                    isOther: true))
        }
        data.points = points
        data.categories = points.map(\.xLabel)
        data.options = options
        data.dataRange = Self.extent(points.map(\.y)).map { 0...$0.upperBound }
    }

    // MARK: - ScatterChart

    mutating func buildScatter() {
        let xField = reader.string("x") ?? "x"
        let yField = reader.string("y") ?? "y"
        data.xField = xField
        data.yField = yField
        var options = ChartOptions()
        options.trend = reader.choice("trend", default: .none)
        let sizeField = reader.string("size")
        var entries = entries(
            x: xField, y: yField, series: reader.string("series"), size: sizeField)
        let numeric = entries.filter { ChartValues.number($0.rawX) != nil }
        if numeric.count < entries.count {
            // One count: add to the rows `entries` already skipped.
            var skipped = entries.count - numeric.count
            if let index = warnings.firstIndex(where: {
                if case .skippedRows = $0 { true } else { false }
            }), case .skippedRows(let earlier) = warnings[index] {
                skipped += earlier
                warnings.remove(at: index)
            }
            warnings.append(.skippedRows(skipped))
        }
        entries = numeric
        data.series = seriesOrder(entries)
        data.points = entries.enumerated().map { index, entry in
            let x = ChartValues.number(entry.rawX) ?? 0
            return ChartPoint(
                id: index, x: .number(x), xLabel: entry.xText, y: entry.y, series: entry.series,
                size: entry.size)
        }
        let xs = data.points.compactMap(\.x.numeric)
        let ys = data.points.map(\.y)
        if options.trend == .linear { options.fit = LinearFit.leastSquares(x: xs, y: ys) }
        if sizeField != nil { options.sizeRange = Self.extent(data.points.compactMap(\.size)) }
        data.xAxis = .number
        data.options = options
        data.xDomain =
            reader.range("xDomain")
            ?? Self.extent(xs).map { NiceScale.domain($0, includeZero: false) }
        // The trend line spans the x domain; keep its ends inside the y domain.
        var yValues = ys
        if let fit = options.fit, let domain = data.xDomain {
            yValues += [fit.y(at: domain.lowerBound), fit.y(at: domain.upperBound)]
        }
        data.dataRange = Self.extent(yValues)
    }

    // MARK: - Heatmap

    mutating func buildHeatmap() {
        let xField = reader.string("x") ?? "x"
        let yField = reader.string("y") ?? "y"
        let valueField = reader.string("value") ?? "value"
        data.xField = xField
        data.yField = yField
        var options = ChartOptions()
        options.heatScale = reader.choice("scale", default: .sequential)
        options.heatLayout = reader.choice("layout", default: .grid)
        let entries = entries(x: xField, y: valueField, row: yField)
        let (axisKind, dates) = axis(for: entries, allowNumber: false)
        var points: [ChartPoint] = []
        var columns: [String] = []
        var rowNames: [String] = []
        if options.heatLayout == .calendar, axisKind == .time {
            // Weeks × weekdays.
            var calendar = Calendar(identifier: .iso8601)
            calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
            let weekdayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
            var weekStarts: [Date] = []
            for (index, entry) in entries.enumerated() {
                guard let date = dates[index] else { continue }
                let weekday = (calendar.component(.weekday, from: date) + 5) % 7
                let start =
                    calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
                if !weekStarts.contains(start) { weekStarts.append(start) }
                let label = ChartDates.shortLabel(start)
                points.append(
                    ChartPoint(
                        id: points.count, x: .category(label), xLabel: entry.xText, y: entry.y,
                        row: weekdayNames[weekday]))
            }
            columns = weekStarts.sorted().map(ChartDates.shortLabel)
            rowNames = weekdayNames.filter { name in points.contains { $0.row == name } }
            // Distinct axis names: x and y often name the same date field.
            data.xField = "week"
            data.yField = "weekday"
        } else {
            columns = categoryOrder(entries, dates: dates)
            var seen = Set<String>()
            for entry in entries {
                if let row = entry.row, seen.insert(row).inserted { rowNames.append(row) }
            }
            points = entries.enumerated().map { index, entry in
                ChartPoint(
                    id: index, x: .category(entry.xText), xLabel: entry.xText, y: entry.y,
                    row: entry.row)
            }
        }
        if data.xField == data.yField { data.yField += " (row)" }
        let cells = columns.count * max(rowNames.count, 1)
        if cells > ChartBudgets.maxHeatmapCells { warnings.append(.tooManyCells(cells)) }
        options.valueRange = Self.extent(points.map(\.y))
        data.points = points
        data.categories = columns
        data.rows = rowNames
        data.xAxis = .category
        data.options = options
        data.dataRange = nil
    }

    // MARK: - Histogram

    mutating func buildHistogram() {
        var options = ChartOptions()
        options.histogramMode = reader.choice(
            "mode", default: reader.choice("show", default: .count))
        let values = (reader.array("values") ?? []).compactMap(ChartValues.number)
        let skipped = (reader.array("values") ?? []).count - values.count
        if skipped > 0 { warnings.append(.skippedRows(skipped)) }
        if values.count > ChartBudgets.maxPoints { warnings.append(.tooManyPoints(values.count)) }
        options.xFormat = data.format
        options.xUnit = data.unit
        data.format = options.histogramMode == .percent ? .percent : .number
        data.unit = nil
        data.xField = options.xUnit.map { "value (\($0))" } ?? "value"
        data.yField = options.histogramMode == .percent ? "percent" : "count"
        data.options = options
        data.xAxis = .number
        guard let low = values.min(), let high = values.max() else { return }
        let requested = reader.number("bins").map { Int($0.rounded()) }
        let binCount = min(
            max(requested ?? HistogramBins.freedmanDiaconisBins(values), 1), ChartBudgets.maxBins)
        let bins = HistogramBins.bins(values, low: low, high: high, count: binCount)
        let total = Double(values.count)
        data.points = bins.enumerated().map { index, bin in
            let y =
                options.histogramMode == .percent
                ? Double(bin.count) / total * 100 : Double(bin.count)
            return ChartPoint(
                id: index, x: .number(bin.lower),
                xLabel: options.xFormat.axisString(bin.lower) + "–"
                    + options.xFormat.axisString(bin.upper),
                xEnd: bin.upper, y: y)
        }
        data.axisFormat = data.format
        data.dataRange = Self.extent(data.points.map(\.y))
        data.xDomain = bins.first.map(\.lower).flatMap { lower in
            bins.last.map { lower...$0.upper }
        }
    }

    // MARK: - Sparkline

    mutating func buildSparkline() {
        var options = ChartOptions()
        options.emphasis = reader.choice("emphasis", default: .last)
        options.filled = reader.bool("filled") ?? false
        options.intent = ChartIntent(reader.string("intent"))
        let raw = reader.array("values") ?? []
        var values = raw.compactMap(ChartValues.number)
        if values.count < raw.count { warnings.append(.skippedRows(raw.count - values.count)) }
        if values.count > ChartBudgets.downsampleThreshold {
            let x = values.indices.map(Double.init)
            let kept = LTTB.indices(x: x, y: values, threshold: ChartBudgets.downsampleThreshold)
            warnings.append(.downsampled(from: values.count, to: kept.count))
            values = kept.map { values[$0] }
        }
        data.points = values.enumerated().map { index, value in
            ChartPoint(id: index, x: .number(Double(index)), xLabel: "\(index + 1)", y: value)
        }
        data.xField = "point"
        data.yField = "value"
        data.xAxis = .number
        data.options = options
        if let range = Self.extent(values) {
            data.dataRange = range
            data.xDomain = 0...Double(max(values.count - 1, 1))
        }
    }

    // MARK: - ComboChart

    mutating func buildCombo() {
        let xField = reader.string("x") ?? "x"
        let barsField = reader.string("bars") ?? "bars"
        let lineField = reader.string("line") ?? "line"
        data.xField = xField
        data.yField = barsField
        var options = ChartOptions()
        options.lineField = lineField
        let barEntries = entries(x: xField, y: barsField)
        let skippedBefore = warnings.count
        let lineEntries = entries(x: xField, y: lineField)
        // One skip count is enough for the journal.
        if warnings.count > skippedBefore { warnings.removeLast(warnings.count - skippedBefore) }
        let categories = categoryOrder(barEntries + lineEntries, dates: [])
        var points: [ChartPoint] = []
        for entry in barEntries {
            points.append(
                ChartPoint(
                    id: points.count, x: .category(entry.xText), xLabel: entry.xText, y: entry.y,
                    series: barsField))
        }
        for entry in lineEntries {
            points.append(
                ChartPoint(
                    id: points.count, x: .category(entry.xText), xLabel: entry.xText, y: entry.y,
                    series: lineField))
        }
        data.points = points
        data.categories = categories
        data.series = [barsField, lineField]
        data.xAxis = .category
        data.options = options
        data.dataRange = Self.extent(points.map(\.y))
    }
}

/// ISO-8601 date parsing for time axes. Parsing happens in `ChartData.make`, never in a body.
enum ChartDates {
    private static let full = Date.ISO8601FormatStyle()
    private static let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    private static let dateOnly = Date.ISO8601FormatStyle().year().month().day()

    /// Parsed row strings (a miss is stored as `nil`), so a streamed date axis parses
    /// each row once, not on every frame. Bounded: cleared at `cacheLimit` entries.
    private static let cache = OSAllocatedUnfairLock(initialState: [String: Date?]())
    static let cacheLimit = 20_000

    /// A date for `2026-11-07` or a full ISO-8601 timestamp; `nil` for anything else.
    static func parse(_ text: String) -> Date? {
        guard text.count >= 10, text.count <= 40, text.contains("-"),
            text.first?.isNumber == true
        else { return nil }
        if let hit = cache.withLock({ $0[text] }) { return hit }
        let date: Date?
        if text.count == 10 {
            date = try? dateOnly.parse(text)
        } else {
            date = (try? full.parse(text)) ?? (try? fractional.parse(text))
        }
        cache.withLock { entries in
            if entries.count >= cacheLimit { entries.removeAll(keepingCapacity: true) }
            entries[text] = date
        }
        return date
    }

    /// "Nov 7" in UTC (calendar heatmap columns).
    static func shortLabel(_ date: Date) -> String {
        var style = Date.FormatStyle().month(.abbreviated).day()
        style.timeZone = TimeZone(identifier: "UTC") ?? .current
        style.locale = Locale(identifier: "en_US_POSIX")
        return date.formatted(style)
    }
}

/// Histogram binning.
public enum HistogramBins {
    public struct Bin: Sendable, Hashable {
        public var lower: Double
        public var upper: Double
        public var count: Int
    }

    /// The Freedman–Diaconis bin count (width `2 · IQR · n^(-1/3)`); Sturges when the IQR
    /// is zero.
    public static func freedmanDiaconisBins(_ values: [Double]) -> Int {
        guard values.count > 1, let low = values.min(), let high = values.max(), high > low
        else { return 1 }
        let sorted = values.sorted()
        let iqr = quantile(sorted, 0.75) - quantile(sorted, 0.25)
        guard iqr > 0 else { return Int((log2(Double(values.count))).rounded(.up)) + 1 }
        let width = 2 * iqr * pow(Double(values.count), -1.0 / 3.0)
        return max(1, Int(((high - low) / width).rounded(.up)))
    }

    /// Linear-interpolated quantile of sorted values.
    static func quantile(_ sorted: [Double], _ q: Double) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let position = q * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, sorted.count - 1)
        let fraction = position - Double(lower)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
    }

    /// Equal-width bins with a nice width that cover `low...high`. The last bin holds
    /// `high`.
    public static func bins(_ values: [Double], low: Double, high: Double, count: Int) -> [Bin] {
        let span = max(high - low, 1e-9)
        let width = high > low ? NiceScale.ceil(span / Double(max(count, 1))) : 1
        let start = (low / width).rounded(.down) * width
        let binCount = max(1, Int(((high - start) / width).rounded(.down)) + 1)
        var counts = Array(repeating: 0, count: binCount)
        for value in values {
            let index = min(max(Int(((value - start) / width).rounded(.down)), 0), binCount - 1)
            counts[index] += 1
        }
        return counts.enumerated().map { index, count in
            Bin(
                lower: start + Double(index) * width, upper: start + Double(index + 1) * width,
                count: count)
        }
    }
}
