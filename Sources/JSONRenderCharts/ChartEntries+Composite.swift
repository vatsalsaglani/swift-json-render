// Owner: jr-3d (wave 2); seeded empty by jr-1b. Append one line per chart.
internal import Charts
internal import Foundation
public import JSONRenderCore
internal import JSONRenderSwiftUI
internal import SwiftUI

extension ChartEntries {
    /// jr-3d's composite charts (waterfall, funnel, box plot, candlestick, treemap), in
    /// VPLAN §7.3 table order.
    static let composite: [ComponentDefinition] = [
        Waterfall.definition,
        Funnel.definition,
        BoxPlot.definition,
        Candlestick.definition,
        Treemap.definition,
    ]

    /// Registers the composite charts (definition and renderer) and their spec rule.
    static func registerComposite(into catalog: inout Catalog) throws(CatalogError) {
        try catalog.register(Waterfall.self)
        try catalog.register(Funnel.self)
        try catalog.register(BoxPlot.self)
        try catalog.register(Candlestick.self)
        try catalog.register(Treemap.self)
        catalog.rule(CompositeChartRules.name, CompositeChartRules.check)
    }
}

// MARK: - Budgets

/// The budgets of the composite charts (VPLAN §7.3).
public enum CompositeBudgets {
    /// Waterfall steps; more fold into "Other".
    public static let maxWaterfallSteps = 12
    /// Funnel stages; more fold into "Other".
    public static let maxFunnelStages = 8
    /// Box plot groups; more is an error.
    public static let maxBoxPlotGroups = 20
    /// Candlestick periods; more are cut to the last ones.
    public static let maxCandlestickPeriods = 180
    /// Treemap cells; more fold into "Other".
    public static let maxTreemapCells = 200
}

// MARK: - Shared data building

/// The decode steps every composite chart shares: format, unit and reference lines first;
/// the y domain last.
enum CompositeData {
    /// A `ChartData` with the format, unit and reference lines read.
    static func start(
        kind: ChartKind, reader: ChartPropReader, warnings: inout [ChartWarning]
    ) -> ChartData {
        var data = ChartData(kind: kind)
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
        return data
    }

    /// Sets `dataRange` and the y domain: the `yDomain` prop, else nice numbers around the
    /// values and the reference lines.
    static func finish(
        _ data: inout ChartData, range: ClosedRange<Double>?, reader: ChartPropReader,
        includeZero: Bool
    ) {
        data.dataRange = range
        var span = range
        for line in data.referenceLines {
            span =
                span.map { min($0.lowerBound, line.value)...max($0.upperBound, line.value) }
                ?? line.value...line.value
        }
        if let fixed = reader.range("yDomain") {
            data.yDomain = fixed
            data.yDomainIsFixed = true
        } else if let span {
            data.yDomain = NiceScale.domain(span, includeZero: includeZero)
        } else {
            data.yDomain = 0...1
        }
    }

    /// The extent of `values`, or `nil` when empty.
    static func extent<S: Sequence>(_ values: S) -> ClosedRange<Double>? where S.Element == Double {
        var low = Double.infinity
        var high = -Double.infinity
        for value in values {
            low = min(low, value)
            high = max(high, value)
        }
        return low <= high ? low...high : nil
    }

    /// Labels made unique: a repeat gets " (2)", " (3)" and so on. Two marks with the same
    /// category would otherwise share one band.
    static func unique(_ labels: [String]) -> [String] {
        var used = Set<String>()
        var counts: [String: Int] = [:]
        return labels.map { label in
            guard used.contains(label) else {
                used.insert(label)
                return label
            }
            var count = counts[label, default: 1]
            var candidate = label
            repeat {
                count += 1
                candidate = "\(label) (\(count))"
            } while used.contains(candidate)
            counts[label] = count
            used.insert(candidate)
            return candidate
        }
    }

    /// The row objects of `data`; rows that are not objects are counted as skipped.
    static func objects(_ reader: ChartPropReader, skipped: inout Int) -> [[String: JSONValue]] {
        var result: [[String: JSONValue]] = []
        for row in reader.array("data") ?? [] {
            if case .object(let fields) = row {
                result.append(fields)
            } else {
                skipped += 1
            }
        }
        return result
    }

    /// The text of a value with a sign: "+32", "−24" (U+2212), "0".
    static func signed(_ value: Double, format: ChartValueFormat) -> String {
        let text = format.axisString(abs(value))
        if value > 0 { return "+" + text }
        if value < 0 { return "\u{2212}" + text }
        return text
    }
}

// MARK: - Axes

extension View {
    /// Pointer selection along the category axis (y for a horizontal chart). Hover only
    /// highlights; a click or an arrow key writes the selection to state.
    func jrCategorySelection(_ input: ChartPlotInput, horizontal: Bool) -> some View {
        jrPointerSelection(input, axis: horizontal ? .y : .x)
    }
}

/// A small legend row: a swatch and a text per entry. Colour is never the only signal: a
/// swatch may be hollow (`filled: false`).
struct CompositeLegend: View {
    struct Entry: Hashable {
        var label: String
        var color: Color
        var filled = true
    }

    let entries: [Entry]
    let input: ChartPlotInput

    var body: some View {
        HStack(spacing: 12) {
            ForEach(entries, id: \.self) { entry in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(entry.filled ? entry.color : .clear)
                        .strokeBorder(entry.color, lineWidth: entry.filled ? 0 : 1)
                        .frame(width: 8, height: 8)
                    Text(entry.label)
                }
            }
        }
        .font(input.tokens.axisFont)
        .foregroundStyle(input.theme.color.textSecondary)
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Spec rules

/// The spec rules of the composite charts (registered as the catalog rule
/// `"charts.composite"`). The checks shared with the other charts (format, domains,
/// reference lines, budgets, the funnel order and the box-plot group limit) are
/// `ChartSpecRules`.
public enum CompositeChartRules {
    public static let name = "charts.composite"

    /// The rule function for `Catalog.rule`.
    public static let check: SpecRule = { spec, state in issues(in: spec, state: state) }

    static let types: Set<String> = [
        ChartKind.waterfall.rawValue, ChartKind.boxPlot.rawValue,
        ChartKind.candlestick.rawValue, ChartKind.treemap.rawValue,
    ]

    /// Every composite-chart issue in `spec`, in element-id order.
    public static func issues(in spec: Spec, state: JSONValue?) -> [SpecIssue] {
        var issues: [SpecIssue] = []
        for id in spec.elements.keys.sorted() {
            guard let element = spec.elements[id], types.contains(element.type) else { continue }
            let context = ChartSpecRules.RuleContext(
                id: id, type: element.type, props: element.props, state: state)
            guard let rows = context.resolved("data")?.arrayValue else { continue }
            for (severity, text) in check(type: element.type, props: element.props, rows: rows) {
                issues.append(
                    SpecIssue(
                        severity: severity, code: .customRule,
                        message: "\(element.type) \(id): \(text)", elementKey: id, rule: name))
            }
        }
        return issues
    }

    /// The rule texts for one element.
    static func check(type: String, props: [String: JSONValue], rows: [JSONValue])
        -> [(SpecIssue.Severity, String)]
    {
        func field(_ name: String, _ fallback: String) -> String {
            props[name]?.stringValue ?? fallback
        }
        switch type {
        case ChartKind.treemap.rawValue:
            let valueField = field("value", "value")
            for (index, row) in rows.enumerated() {
                if let value = ChartValues.number(row[valueField]), value <= 0 {
                    return [
                        (
                            .error,
                            "row \(index + 1) has the value \(ChartValueFormat.number.axisString(value)); a treemap shows only values greater than zero."
                        )
                    ]
                }
            }
        case ChartKind.candlestick.rawValue:
            let names = ["open", "high", "low", "close"].map { field($0, $0) }
            for (index, row) in rows.enumerated() {
                let values = names.map { ChartValues.number(row[$0]) }
                guard let open = values[0], let high = values[1], let low = values[2],
                    let close = values[3]
                else { continue }
                if low > high || open < low || open > high || close < low || close > high {
                    return [
                        (
                            .error,
                            "row \(index + 1): open and close must be between low and high."
                        )
                    ]
                }
            }
        case ChartKind.boxPlot.rawValue:
            for (index, row) in rows.enumerated() {
                let keys = ["min", "q1", "median", "q3", "max"]
                let stats = keys.compactMap { ChartValues.number(row[$0]) }
                if stats.count == keys.count, stats != stats.sorted() {
                    return [
                        (.error, "row \(index + 1): min ≤ q1 ≤ median ≤ q3 ≤ max is not true.")
                    ]
                }
            }
        case ChartKind.waterfall.rawValue:
            let labelField = field("label", "label")
            let labels = Set(rows.compactMap { ChartValues.text($0[labelField]) })
            let missing = (props["subtotals"]?.arrayValue ?? []).compactMap(\.stringValue)
                .filter { !labels.contains($0) }
            if !missing.isEmpty {
                return [
                    (
                        .warning,
                        "subtotals \(missing.joined(separator: ", ")) match no row label."
                    )
                ]
            }
        default:
            break
        }
        return []
    }
}
