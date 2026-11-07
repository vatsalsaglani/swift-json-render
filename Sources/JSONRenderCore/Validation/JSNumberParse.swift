/// JavaScript `Number(value)` and `String.prototype.trim` for the validation functions.
enum JSNumberParse {
    /// ECMAScript `StringToNumber`: trims JavaScript whitespace; `""` is 0; accepts
    /// `[+-]digits[.digits][e[+-]digits]`, `.digits`, `[+-]Infinity`, and unsigned `0x`, `0o`,
    /// `0b` literals. Anything else is `NaN`.
    static func number(_ text: String) -> Double {
        let trimmed = trim(text)
        if trimmed.isEmpty { return 0 }
        switch trimmed {
        case "Infinity", "+Infinity": return .infinity
        case "-Infinity": return -.infinity
        default: break
        }
        let scalars = Array(trimmed.unicodeScalars)
        if scalars.count > 2, scalars[0] == "0" {
            let radix: Double? =
                switch scalars[1] {
                case "x", "X": 16
                case "o", "O": 8
                case "b", "B": 2
                default: nil
                }
            if let radix { return integer(scalars.dropFirst(2), radix: radix) }
        }
        guard isDecimalLiteral(scalars), let value = Double(trimmed) else { return .nan }
        return value
    }

    /// `Number(value)` for a JSON value: booleans are 0 and 1, `null` is 0, arrays go
    /// through their string form, objects are `NaN`.
    static func number(of value: JSONValue) -> Double {
        switch value {
        case .null: 0
        case .bool(let flag): flag ? 1 : 0
        case .number(let number): number
        case .string(let text): number(text)
        case .array: number(value.jsString)
        case .object: .nan
        }
    }

    /// `String.prototype.trim`.
    static func trim(_ text: String) -> Substring {
        let scalars = text.unicodeScalars
        guard let start = scalars.firstIndex(where: { !isWhitespace($0) }),
            let end = scalars.lastIndex(where: { !isWhitespace($0) })
        else { return "" }
        return Substring(scalars[start...end])
    }

    /// ECMAScript `WhiteSpace` and `LineTerminator`.
    static func isWhitespace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029,
            0x202F, 0x205F, 0x3000, 0xFEFF:
            true
        default:
            false
        }
    }

    private static func integer(_ digits: ArraySlice<Unicode.Scalar>, radix: Double) -> Double {
        var result = 0.0
        for scalar in digits {
            guard let digit = Int(String(scalar), radix: 16), Double(digit) < radix else {
                return .nan
            }
            result = result * radix + Double(digit)
        }
        return result
    }

    /// `StrDecimalLiteral` without `Infinity`.
    private static func isDecimalLiteral(_ scalars: [Unicode.Scalar]) -> Bool {
        var index = 0
        func digits() -> Int {
            let start = index
            while index < scalars.count, ("0"..."9").contains(scalars[index]) { index += 1 }
            return index - start
        }
        if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" { index += 1 }
        var mantissa = digits()
        if index < scalars.count, scalars[index] == "." {
            index += 1
            mantissa += digits()
        }
        guard mantissa > 0 else { return false }
        if index < scalars.count, scalars[index] == "e" || scalars[index] == "E" {
            index += 1
            if index < scalars.count, scalars[index] == "+" || scalars[index] == "-" { index += 1 }
            guard digits() > 0 else { return false }
        }
        return index == scalars.count
    }
}
