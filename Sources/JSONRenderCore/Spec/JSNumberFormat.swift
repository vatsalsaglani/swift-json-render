/// ECMAScript `Number::toString(10)` for `Double`.
///
/// Swift's `description` already gives the shortest round-trip digits. This type takes
/// those digits and lays them out the way JavaScript does: integers below 1e21 without a
/// fraction (`"3"`, not `"3.0"`), fixed notation down to 1e-6, exponent notation with an
/// explicit sign outside that range (`"1e+21"`, `"1e-7"`), `"0"` for `-0`.
enum JSNumberFormat {
    static func string(_ value: Double) -> String {
        if value.isNaN { return "NaN" }
        if value.isInfinite { return value < 0 ? "-Infinity" : "Infinity" }
        if value == 0 { return "0" }
        let sign = value < 0 ? "-" : ""
        let (digits, exponent) = decompose(abs(value))
        return sign + layout(digits: digits, n: exponent)
    }

    /// Returns the significant digits `s` (no leading or trailing zeros) and `n` such that
    /// the value is `0.s × 10^n`.
    private static func decompose(_ value: Double) -> (digits: [Character], n: Int) {
        let text = value.description  // e.g. "123.45", "1e-07", "1.5e+300", "100.0"
        var mantissa = Substring(text)
        var exponent = 0
        if let eIndex = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
            mantissa = text[text.startIndex..<eIndex]
            exponent = Int(text[text.index(after: eIndex)...]) ?? 0
        }
        var integerPart = Substring(mantissa)
        var fractionPart = Substring("")
        if let dot = mantissa.firstIndex(of: ".") {
            integerPart = mantissa[mantissa.startIndex..<dot]
            fractionPart = mantissa[mantissa.index(after: dot)...]
        }
        var all = Array(integerPart) + Array(fractionPart)
        var pointPosition = integerPart.count + exponent
        while let first = all.first, first == "0" {
            all.removeFirst()
            pointPosition -= 1
        }
        while let last = all.last, last == "0" {
            all.removeLast()
        }
        if all.isEmpty { return (["0"], 1) }
        return (all, pointPosition)
    }

    private static func layout(digits: [Character], n: Int) -> String {
        let k = digits.count
        let s = String(digits)
        if k <= n && n <= 21 {
            return s + String(repeating: "0", count: n - k)
        }
        if 0 < n && n <= 21 {
            return String(digits[0..<n]) + "." + String(digits[n...])
        }
        if -6 < n && n <= 0 {
            return "0." + String(repeating: "0", count: -n) + s
        }
        let e = n - 1
        let exponent = e < 0 ? "-\(-e)" : "+\(e)"
        if k == 1 {
            return s + "e" + exponent
        }
        return String(digits[0]) + "." + String(digits[1...]) + "e" + exponent
    }
}
