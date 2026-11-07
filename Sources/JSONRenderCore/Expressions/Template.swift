/// The `${…}` interpolation shared by `$template` and action `confirm` text.
///
/// Matches the upstream regular expression `/\$\{([^}]+)\}/g`: `${` then one or more
/// characters other than `}`, then `}`. `${}` and an unclosed `${` stay literal.
enum Template {
    static func interpolate(_ template: String, _ replacement: (String) -> String) -> String {
        guard template.contains("${") else { return template }
        var result = ""
        var index = template.startIndex
        while index < template.endIndex {
            if template[index...].hasPrefix("${") {
                let start = template.index(index, offsetBy: 2)
                if let close = template[start...].firstIndex(of: "}"), close > start {
                    result += replacement(String(template[start..<close]))
                    index = template.index(after: close)
                    continue
                }
            }
            result.append(template[index])
            index = template.index(after: index)
        }
        return result
    }

    /// `$template`: `${/abs}` reads state; `${bare}` reads the repeat item first, then state
    /// at `/bare`. `nil` and `null` give `""`; other values use JavaScript `String()`.
    static func render(_ template: String, state: JSONValue, repeatItem: JSONValue?) -> String {
        interpolate(template) { rawPath in
            if rawPath.hasPrefix("/") {
                return text(state.value(at: JSONPointer(lenient: rawPath)))
            }
            if let repeatItem, let fromItem = repeatItem.value(at: JSONPointer(lenient: rawPath)),
                fromItem != .null
            {
                return fromItem.jsString
            }
            return text(state.value(at: JSONPointer(lenient: "/" + rawPath)))
        }
    }

    /// Upstream `interpolateString` (action `confirm` text): every `${path}` reads state only.
    static func interpolateState(_ template: String, state: JSONValue) -> String {
        interpolate(template) { path in text(state.value(at: JSONPointer(lenient: path))) }
    }

    private static func text(_ value: JSONValue?) -> String {
        guard let value, value != .null else { return "" }
        return value.jsString
    }
}
