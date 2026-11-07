public import Foundation

/// How a chart prints a value: the `format` prop.
///
/// `percent` values are already percentages (`72` prints `72 %`). `bytes` uses binary
/// steps (1,024). `duration` takes seconds. Output uses tabular-friendly short forms:
/// `1.2k`, `3.4 MB`, `41 s`, `72 %`, `$3.60`.
public enum ChartValueFormat: Sendable, Hashable {
    case number
    case compact
    case percent
    /// An ISO 4217 code, for example `USD`.
    case currency(String)
    case duration
    case bytes

    /// The format named by `raw`; `nil` raw gives `.number`. An unknown name gives `nil`.
    public init?(_ raw: String?) {
        guard let raw, !raw.isEmpty else {
            self = .number
            return
        }
        switch raw {
        case "number": self = .number
        case "compact": self = .compact
        case "percent": self = .percent
        case "duration": self = .duration
        case "bytes": self = .bytes
        default:
            let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2, parts[0] == "currency",
                parts[1].count == 3, parts[1].allSatisfy({ $0.isLetter && $0.isASCII })
            else { return nil }
            self = .currency(parts[1].uppercased())
        }
    }

    /// `true` when the format already says what the unit is.
    var carriesUnit: Bool {
        switch self {
        case .percent, .currency, .duration, .bytes: true
        case .number, .compact: false
        }
    }

    /// The text for `value`, with ` unit` appended when the format has no unit of its own.
    public func string(_ value: Double, unit: String? = nil, locale: Locale = .current) -> String {
        let text = axisString(value, locale: locale)
        guard let unit, !unit.isEmpty, !carriesUnit else { return text }
        return text + " " + unit
    }

    /// The text for an axis tick: no unit (the axis title or caption names it).
    public func axisString(_ value: Double, locale: Locale = .current) -> String {
        guard value.isFinite else { return "–" }
        switch self {
        case .number:
            return Self.decimal(value, digits: abs(value) >= 100 ? 0 : 2, locale: locale)
        case .compact:
            return Self.compact(value, locale: locale)
        case .percent:
            return Self.decimal(value, digits: 1, locale: locale) + " %"
        case .currency(let code):
            return value.formatted(
                .currency(code: code).precision(.fractionLength(2)).locale(locale))
        case .duration:
            return Self.duration(value, locale: locale)
        case .bytes:
            return Self.bytes(value, locale: locale)
        }
    }

    private static func decimal(_ value: Double, digits: Int, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)).locale(locale))
    }

    private static func compact(_ value: Double, locale: Locale) -> String {
        let magnitude = abs(value)
        let steps: [(Double, String)] = [(1e12, "T"), (1e9, "B"), (1e6, "M"), (1e3, "k")]
        for (size, suffix) in steps where magnitude >= size * 0.9995 {
            return decimal(value / size, digits: 1, locale: locale) + suffix
        }
        return decimal(value, digits: 1, locale: locale)
    }

    private static func duration(_ seconds: Double, locale: Locale) -> String {
        let magnitude = abs(seconds)
        let sign = seconds < 0 ? "−" : ""
        if magnitude < 1 {
            return sign + decimal(magnitude * 1000, digits: 0, locale: locale) + " ms"
        }
        if magnitude < 60 { return sign + decimal(magnitude, digits: 1, locale: locale) + " s" }
        let total = Int(magnitude.rounded())
        if total < 3600 { return sign + "\(total / 60)m \(total % 60)s" }
        return sign + "\(total / 3600)h \((total % 3600) / 60)m"
    }

    private static func bytes(_ value: Double, locale: Locale) -> String {
        let magnitude = abs(value)
        let units = ["B", "KB", "MB", "GB", "TB"]
        var index = 0
        var scaled = magnitude
        while scaled >= 1024, index < units.count - 1 {
            scaled /= 1024
            index += 1
        }
        let signed = value < 0 ? -scaled : scaled
        return decimal(signed, digits: index == 0 ? 0 : 1, locale: locale) + " " + units[index]
    }
}
