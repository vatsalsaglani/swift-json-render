internal import Foundation
internal import JSONRenderCore

/// The chart components this module ships. The raw value is the element `type`.
public enum ChartKind: String, Sendable, Hashable, CaseIterable {
    case bar = "BarChart"
    case line = "LineChart"
    case area = "AreaChart"
    case pie = "PieChart"
    case gauge = "Gauge"
    case sparkline = "Sparkline"
    case scatter = "ScatterChart"
    case heatmap = "Heatmap"
    case histogram = "Histogram"
    case combo = "ComboChart"
    case waterfall = "Waterfall"
    case funnel = "Funnel"
    case boxPlot = "BoxPlot"
    case candlestick = "Candlestick"
    case treemap = "Treemap"

    /// The spoken name, for example "Bar chart".
    public var spokenName: String {
        switch self {
        case .bar: "Bar chart"
        case .line: "Line chart"
        case .area: "Area chart"
        case .pie: "Pie chart"
        case .gauge: "Gauge"
        case .sparkline: "Sparkline"
        case .scatter: "Scatter chart"
        case .heatmap: "Heatmap"
        case .histogram: "Histogram"
        case .combo: "Combo chart"
        case .waterfall: "Waterfall chart"
        case .funnel: "Funnel chart"
        case .boxPlot: "Box plot"
        case .candlestick: "Candlestick chart"
        case .treemap: "Treemap"
        }
    }
}

/// A status meaning for a reference line, a band or a sparkline.
public enum ChartIntent: String, Sendable, Hashable, CaseIterable {
    case good, warning, critical, info

    /// Accepts `good|warn|risk|info` (VPLAN) and `warning|critical` (theme names).
    public init?(_ raw: String?) {
        switch raw {
        case "good": self = .good
        case "warn", "warning": self = .warning
        case "risk", "critical": self = .critical
        case "info": self = .info
        default: return nil
        }
    }

    /// The names a spec may use.
    public static let acceptedNames = ["good", "warn", "risk", "info", "warning", "critical"]
}

/// The `legend` prop.
public enum ChartLegendMode: String, Sendable, Hashable, CaseIterable {
    case auto, bottom, trailing, hidden
}

/// The `height` prop: 96, 160 or 240 points.
public enum ChartHeight: String, Sendable, Hashable, CaseIterable {
    case compact, regular, tall

    public var points: Double {
        switch self {
        case .compact: 96
        case .regular: 160
        case .tall: 240
        }
    }
}

/// The `variant` prop: `minimal` hides the axes, `dense` uses smaller type for board cards.
public enum ChartVariant: String, Sendable, Hashable, CaseIterable {
    case `default`, minimal, dense
}

/// A `referenceLines` entry.
public struct ChartReferenceLine: Sendable, Hashable {
    public var value: Double
    public var label: String?
    public var intent: ChartIntent?

    public init(value: Double, label: String? = nil, intent: ChartIntent? = nil) {
        self.value = value
        self.label = label
        self.intent = intent
    }
}

/// The prop schemas every chart shares. Chart definitions add their own fields between
/// the data fields and these.
public enum ChartProps {
    static let formatDescription =
        "number | compact | percent | currency:<ISO code> | duration | bytes. Default number."

    /// `data`: an array of row objects, or `{ "$state": "/rows" }`.
    static let data = PropSchema.Field(
        name: "data", schema: .array(.record(.any)),
        description: "Rows: an array literal or { \"$state\": \"/rows\" }. Charts never fetch.")

    static func field(_ name: String, _ description: String, optional: Bool = false)
        -> PropSchema.Field
    {
        PropSchema.Field(
            name: name, schema: optional ? PropSchema.string.optional() : .string,
            description: description)
    }

    static func choice(_ name: String, _ values: [String], _ description: String)
        -> PropSchema.Field
    {
        PropSchema.Field(
            name: name, schema: PropSchema.enum(values).optional(), description: description)
    }

    static let format = PropSchema.Field(
        name: "format", schema: PropSchema.string.optional(), description: formatDescription)
    static let unit = PropSchema.Field(
        name: "unit", schema: PropSchema.string.optional(),
        description: "Names the axis, for example \"s\". Never two units on one chart.")
    static let referenceLines = PropSchema.Field(
        name: "referenceLines",
        schema: PropSchema.array(
            .object([
                .init(name: "value", schema: .number),
                .init(name: "label", schema: PropSchema.string.optional()),
                .init(
                    name: "intent",
                    schema: PropSchema.enum(ChartIntent.acceptedNames).optional()),
            ])
        ).optional(),
        description: "A budget or threshold line. Give a label with an intent.")
    static let yDomain = PropSchema.Field(
        name: "yDomain", schema: PropSchema.array(.number).optional(),
        description: "[min, max]. Default: nice numbers; bars start at zero.")
    static let xDomain = PropSchema.Field(
        name: "xDomain", schema: PropSchema.array(.number).optional(),
        description: "[min, max] for a numeric x axis.")
    static let legend = choice(
        "legend", ChartLegendMode.allCases.map(\.rawValue),
        "Default auto: a legend only when there are two or more series.")
    static let height = choice(
        "height", ChartHeight.allCases.map(\.rawValue), "96 / 160 / 240 pt. Default regular.")
    static let emptyText = PropSchema.Field(
        name: "emptyText", schema: PropSchema.string.optional(),
        description: "Shown when there is no data.")
    static let selection = PropSchema.Field(
        name: "selection", schema: PropSchema.any.optional(),
        description:
            "Bind with { \"$bindState\": \"/picked\" }. The chart writes the selected x or label.")
    static let summary = PropSchema.Field(
        name: "summary", schema: PropSchema.string.optional(),
        description: "VoiceOver text. Generated when missing.")
    static let variant = choice(
        "variant", ChartVariant.allCases.map(\.rawValue),
        "minimal hides the axes; dense uses smaller type.")
    static let title = PropSchema.Field(
        name: "title", schema: PropSchema.string.optional(), description: "A short heading.")
    static let caption = PropSchema.Field(
        name: "caption", schema: PropSchema.string.optional(),
        description: "One line under the chart.")

    /// The chrome props every chart accepts, after its own fields.
    static func chrome(selection hasSelection: Bool = true, domains: Bool = true)
        -> [PropSchema.Field]
    {
        var fields: [PropSchema.Field] = [format, unit]
        if domains { fields += [yDomain, referenceLines] }
        fields += [legend, height]
        if hasSelection { fields.append(selection) }
        fields += [emptyText, summary, variant, title, caption]
        return fields
    }

    /// The slot names every chart accepts.
    static let slots = ["title", "caption", "empty", "tooltip"]
}

// MARK: - Reading resolved props

/// Typed access to resolved props (`nil` = undefined).
struct ChartPropReader {
    let props: [String: JSONValue?]

    init(_ props: [String: JSONValue?]) {
        self.props = props
    }

    func value(_ name: String) -> JSONValue? {
        guard let value = props[name] ?? nil, value != .null else { return nil }
        return value
    }

    func string(_ name: String) -> String? {
        switch value(name) {
        case .string(let text)?: text.isEmpty ? nil : text
        case .number?, .bool?: value(name)?.jsString
        default: nil
        }
    }

    func number(_ name: String) -> Double? {
        switch value(name) {
        case .number(let number)?: number.isFinite ? number : nil
        case .string(let text)?: Double(text.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    func bool(_ name: String) -> Bool? {
        switch value(name) {
        case .bool(let flag)?: flag
        case .string("true")?: true
        case .string("false")?: false
        default: nil
        }
    }

    func array(_ name: String) -> [JSONValue]? { value(name)?.arrayValue }

    func choice<T: RawRepresentable>(_ name: String, default fallback: T) -> T
    where T.RawValue == String {
        string(name).flatMap(T.init(rawValue:)) ?? fallback
    }

    /// `[min, max]` with min ≤ max; anything else gives `nil`.
    func range(_ name: String) -> ClosedRange<Double>? {
        guard let items = array(name), items.count == 2,
            let low = items[0].numberValue, let high = items[1].numberValue,
            low.isFinite, high.isFinite, low <= high
        else { return nil }
        return low...high
    }

    var referenceLines: [ChartReferenceLine] {
        (array("referenceLines") ?? []).compactMap { item in
            guard let value = ChartValues.number(item["value"]) else { return nil }
            return ChartReferenceLine(
                value: value, label: item["label"]?.stringValue,
                intent: ChartIntent(item["intent"]?.stringValue))
        }
    }
}

/// Field reading inside a data row.
enum ChartValues {
    static func number(_ value: JSONValue?) -> Double? {
        switch value {
        case .number(let number)?: number.isFinite ? number : nil
        case .string(let text)?:
            Double(text.trimmingCharacters(in: .whitespaces)).flatMap { $0.isFinite ? $0 : nil }
        default: nil
        }
    }

    static func text(_ value: JSONValue?) -> String? {
        switch value {
        case .string(let text)?: text
        case .number?, .bool?: value?.jsString
        default: nil
        }
    }
}
