public import Foundation
public import JSONRenderCore

/// The resolved props of a `Gauge`.
public struct GaugeModel: Sendable, Hashable {
    public enum Style: String, Sendable, Hashable, CaseIterable { case arc, ring, linear }

    public struct Band: Sendable, Hashable {
        public var upTo: Double
        public var intent: ChartIntent
    }

    public var value: Double
    public var min: Double
    public var max: Double
    public var label: String?
    public var unit: String?
    public var target: Double?
    /// Bands sorted by `upTo`.
    public var bands: [Band]
    public var style: Style
    public var format: ChartValueFormat

    /// The value's position in `min...max`, clamped to 0...1.
    public var fraction: Double {
        guard max > min else { return 0 }
        return Swift.min(Swift.max((value - min) / (max - min), 0), 1)
    }

    /// The target's position, clamped to 0...1.
    public var targetFraction: Double? {
        guard let target, max > min else { return nil }
        return Swift.min(Swift.max((target - min) / (max - min), 0), 1)
    }

    /// The band the value falls in, or `nil` without bands.
    public var currentIntent: ChartIntent? {
        bands.first(where: { value <= $0.upTo })?.intent ?? bands.last?.intent
    }

    public func valueText(locale: Locale = .current) -> String {
        format.string(value, unit: unit, locale: locale)
    }

    /// "of $5.00 · 72 %" (or "of 100" without a share for percent values).
    public func rangeText(locale: Locale = .current) -> String {
        let maxText = format.string(max, unit: unit, locale: locale)
        if format == .percent, min == 0, max == 100 { return "of \(maxText)" }
        let share = ChartValueFormat.percent.axisString(fraction * 100, locale: locale)
        return "of \(maxText) · \(share)"
    }

    /// The default VoiceOver summary.
    public func summary(locale: Locale = .current) -> String {
        var parts = ["Gauge"]
        if let label { parts.append(label) }
        parts.append("\(valueText(locale: locale)) \(rangeText(locale: locale))")
        if let target {
            parts.append("target \(format.string(target, unit: unit, locale: locale))")
        }
        return parts.joined(separator: ", ")
    }

    /// Decodes resolved props. `max` defaults to 100, `min` to 0; `max ≤ min` gives
    /// `min + 1`.
    public static func make(props: [String: JSONValue?]) -> GaugeModel {
        let reader = ChartPropReader(props)
        let low = reader.number("min") ?? 0
        var high = reader.number("max") ?? 100
        if high <= low { high = low + 1 }
        let bands: [Band] = (reader.array("bands") ?? []).compactMap { item in
            guard let upTo = ChartValues.number(item["to"]),
                let intent = ChartIntent(item["intent"]?.stringValue)
            else { return nil }
            return Band(upTo: upTo, intent: intent)
        }.sorted { $0.upTo < $1.upTo }
        return GaugeModel(
            value: reader.number("value") ?? 0, min: low, max: high,
            label: reader.string("label"), unit: reader.string("unit"),
            target: reader.number("target"), bands: bands,
            style: reader.choice("style", default: .arc),
            format: ChartValueFormat(reader.string("format")) ?? .number)
    }
}
