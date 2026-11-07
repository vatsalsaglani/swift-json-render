// Owner: jr-1b (wave 1). Runtime helpers that `@JRComponent` initialisers call.
public import Foundation

/// Prop coercion for macro-generated initialisers. Each function takes the resolved prop
/// (`nil` = undefined) and returns `nil` when the value cannot be used.
public enum JRPropDecode {
    /// A string; numbers and Booleans use their JavaScript string form.
    public static func string(_ value: JSONValue?) -> String? {
        switch value {
        case .string(let text)?: text
        case .number?, .bool?: value?.jsString
        default: nil
        }
    }

    /// A number; a numeric string is parsed.
    public static func double(_ value: JSONValue?) -> Double? {
        switch value {
        case .number(let number)?: number
        case .string(let text)?: Double(text.trimmingCharacters(in: .whitespaces))
        default: nil
        }
    }

    public static func float(_ value: JSONValue?) -> Float? { double(value).map(Float.init) }

    public static func cgFloat(_ value: JSONValue?) -> CGFloat? {
        double(value).map { CGFloat($0) }
    }

    /// A rounded integer; values outside `Int` give `nil`.
    public static func int(_ value: JSONValue?) -> Int? {
        guard let number = double(value), number.isFinite else { return nil }
        return Int(exactly: number.rounded())
    }

    /// A Boolean; the strings `"true"` and `"false"` are accepted.
    public static func bool(_ value: JSONValue?) -> Bool? {
        switch value {
        case .bool(let flag)?: flag
        case .string("true")?: true
        case .string("false")?: false
        default: nil
        }
    }

    /// Any value except undefined; `null` counts as absent.
    public static func json(_ value: JSONValue?) -> JSONValue? {
        value == .null ? nil : value
    }

    /// An array whose elements decode with `element`; elements that do not decode are
    /// dropped.
    public static func array<T>(_ element: @escaping (JSONValue?) -> T?) -> (JSONValue?) -> [T]? {
        { value in
            guard case .array(let items)? = value else { return nil }
            return items.compactMap { element($0) }
        }
    }
}
