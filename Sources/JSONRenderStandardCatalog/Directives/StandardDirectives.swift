// Owner: jr-3 (wave 2). The four shipped directives (upstream packages/directives).
public import JSONRenderCore
internal import Foundation

extension StandardEntries {
    /// `$format`, `$count`, `$join`, `$pluralize`, with upstream names, schemas and
    /// descriptions. `Catalog.standard` registers them, so `prompt()` lists them under
    /// CUSTOM DYNAMIC VALUES.
    public static let standardDirectives: [DirectiveDefinition] = [
        StandardDirectives.format, StandardDirectives.count, StandardDirectives.join,
        StandardDirectives.pluralize,
    ].compactMap { $0 }
}

/// The directive implementations. Each resolves its operand first (so it composes with
/// `$state`, `$item` and other directives), then computes a value. Specs never carry code.
enum StandardDirectives {
    /// `{ "$format": "date" | "currency" | "number" | "percent", "value": …, "locale"?,
    /// "currency"?, "notation"?, "style"?, "options"?, "now"? }`.
    ///
    /// Swift deviations: `options` is accepted and ignored (Intl options have no portable
    /// mapping); `notation` supports `"compact"`; `locale` defaults to `Locale.current`;
    /// dates are numbers (milliseconds since 1970) or ISO 8601 strings.
    static let format = try? DirectiveDefinition(
        name: "$format",
        description:
            "Locale-aware value formatting (date, currency, number, percent). Supports style: \"relative\" for relative dates.",
        schema: .object([
            .init(name: "$format", schema: .enum(["date", "currency", "number", "percent"])),
            .init(name: "value", schema: .any),
            .init(name: "locale", schema: PropSchema.string.optional()),
            .init(name: "currency", schema: PropSchema.string.optional()),
            .init(name: "notation", schema: PropSchema.string.optional()),
            .init(name: "style", schema: PropSchema.string.optional()),
            .init(name: "options", schema: PropSchema.record(.any).optional()),
            .init(name: "now", schema: PropSchema.number.optional()),
        ])
    ) { raw, resolver in
        guard case .string(let kind)? = raw["$format"] else { return nil }
        let value = raw["value"].flatMap { resolver.resolveValue($0) }
        let locale = raw["locale"]?.stringValue.map(Locale.init(identifier:)) ?? .current
        switch kind {
        case "date":
            guard let date = DirectiveValue.date(value) else { return nil }
            if raw["style"] == .string("relative") {
                let now = raw["now"]?.numberValue ?? Date().timeIntervalSince1970 * 1000
                return .string(DirectiveValue.relative(milliseconds: now - date))
            }
            let style = Date.FormatStyle(date: .numeric, time: .omitted, locale: locale)
            return .string(Date(timeIntervalSince1970: date / 1000).formatted(style))
        case "currency":
            guard let number = DirectiveValue.number(value) else { return nil }
            let code = raw["currency"]?.stringValue ?? "USD"
            return .string(number.formatted(.currency(code: code).locale(locale)))
        case "number":
            guard let number = DirectiveValue.number(value) else { return nil }
            if raw["notation"] == .string("compact") {
                // Half away from zero, as JavaScript Intl (Foundation defaults to half even).
                return .string(
                    number.formatted(
                        .number.notation(.compactName).rounded(rule: .toNearestOrAwayFromZero)
                            .locale(locale)))
            }
            return .string(
                number.formatted(
                    .number.precision(.fractionLength(0...3)).rounded(rule: .toNearestOrAwayFromZero)
                        .locale(locale)))
        case "percent":
            guard let number = DirectiveValue.number(value) else { return nil }
            return .string(
                number.formatted(
                    .percent.precision(.fractionLength(0...0)).rounded(rule: .toNearestOrAwayFromZero)
                        .locale(locale)))
        default:
            return value
        }
    }

    /// `{ "$count": … }`: the length of an array or string (UTF-16 units, as JavaScript),
    /// else 0.
    static let count = try? DirectiveDefinition(
        name: "$count", description: "Get the length of an array or string.",
        schema: .object([.init(name: "$count", schema: .any)])
    ) { raw, resolver in
        switch raw["$count"].flatMap({ resolver.resolveValue($0) }) {
        case .array(let items)?: .number(Double(items.count))
        case .string(let text)?: .number(Double(text.utf16.count))
        default: .number(0)
        }
    }

    /// `{ "$join": [...], "separator"?: ", " }`: `null` items join as `""`; a non-array is
    /// its JavaScript string; undefined or `null` is `""`.
    static let join = try? DirectiveDefinition(
        name: "$join", description: "Join array elements with a separator.",
        schema: .object([
            .init(name: "$join", schema: .any),
            .init(name: "separator", schema: PropSchema.string.optional()),
        ])
    ) { raw, resolver in
        let separator = raw["separator"]?.stringValue ?? ", "
        switch raw["$join"].flatMap({ resolver.resolveValue($0) }) {
        case .array(let items)?:
            return .string(
                items.map { $0 == .null ? "" : $0.jsString }.joined(separator: separator))
        case nil, .null?:
            return .string("")
        case let value?:
            return .string(value.jsString)
        }
    }

    /// `{ "$pluralize": n, "zero"?, "one", "other" }`: `"1 item"`, `"3 items"`, or `zero`
    /// verbatim for 0. A value that is not a number counts as 0.
    static let pluralize = try? DirectiveDefinition(
        name: "$pluralize",
        description:
            "Select singular/plural/zero form based on count. Output: \"3 items\", \"1 item\", or \"no items\".",
        schema: .object([
            .init(name: "$pluralize", schema: .any),
            .init(name: "zero", schema: PropSchema.string.optional()),
            .init(name: "one", schema: .string),
            .init(name: "other", schema: .string),
        ])
    ) { raw, resolver in
        let count = DirectiveValue.jsNumber(raw["$pluralize"].flatMap { resolver.resolveValue($0) })
        if count == 0, let zero = raw["zero"], zero != .null { return .string(zero.jsString) }
        let text = JSONValue.number(count).jsString
        if count == 1 { return .string("\(text) \(raw["one"]?.jsString ?? "")") }
        return .string("\(text) \(raw["other"]?.jsString ?? "")")
    }
}

/// JavaScript-like coercions for the directives.
enum DirectiveValue {
    /// A number, or a numeric string.
    static func number(_ value: JSONValue?) -> Double? {
        switch value {
        case .number(let number)?: number
        case .string(let text)?: Double(text.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    /// JavaScript `Number(value)`, with `NaN` as 0.
    static func jsNumber(_ value: JSONValue?) -> Double {
        let number: Double? =
            switch value {
            case .number(let number)?: number
            case .bool(let flag)?: flag ? 1 : 0
            case .null?: 0
            case .string(let text)?:
                text.trimmingCharacters(in: .whitespaces).isEmpty
                    ? 0 : Double(text.trimmingCharacters(in: .whitespaces))
            default: nil
            }
        guard let number, !number.isNaN else { return 0 }
        return number
    }

    /// Milliseconds since 1970 from a number or an ISO 8601 string.
    static func date(_ value: JSONValue?) -> Double? {
        switch value {
        case .number(let number)?:
            return number.isFinite ? number : nil
        case .string(let text)?:
            let full = ISO8601DateFormatter()
            full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = full.date(from: text) { return date.timeIntervalSince1970 * 1000 }
            let plain = ISO8601DateFormatter()
            if let date = plain.date(from: text) { return date.timeIntervalSince1970 * 1000 }
            let day = ISO8601DateFormatter()
            day.formatOptions = [.withFullDate]
            if let date = day.date(from: text) { return date.timeIntervalSince1970 * 1000 }
            return nil
        default:
            return nil
        }
    }

    /// Upstream relative time: integer division, the largest unit only.
    static func relative(milliseconds diff: Double) -> String {
        if diff == 0 { return "just now" }
        let suffix = diff > 0 ? "ago" : "from now"
        let seconds = Int((abs(diff) / 1000).rounded(.down))
        let minutes = seconds / 60
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d \(suffix)" }
        if hours > 0 { return "\(hours)h \(suffix)" }
        if minutes > 0 { return "\(minutes)m \(suffix)" }
        return "\(seconds)s \(suffix)"
    }
}
