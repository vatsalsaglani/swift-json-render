/// The guard in front of the `pattern` check.
///
/// Swift `Regex` backtracks with no budget and cannot be cancelled, and the pattern comes
/// from the spec (model output) while the value comes from keystrokes on the main actor.
/// `^(a+)+$` against 20 × `a` + `!` takes about 49 s in a release build. The guard refuses
/// the pattern shapes that cause exponential backtracking and caps both inputs, so the check
/// fails fast instead.
///
/// Refused:
/// - a pattern longer than `maxPatternLength` UTF-16 units;
/// - a value longer than `maxValueLength` UTF-16 units;
/// - a group repeated by `*`, `+`, `{n,}` or `{n,m}` (with `m > 1`) whose body holds an
///   unescaped quantifier outside a character class: `(a+)+`, `(\w+\s?)*`, `(a*)*`,
///   `(x?)+`, `((a+)b){2,}`.
///
/// Allowed: escaped parentheses (`\(a+\)+`), parentheses in a class (`[(a+)]+`), and a group
/// with an inner quantifier repeated at most once (`(\.\d+)?`, `(a+){1}`), because one
/// optional repetition cannot multiply the backtracking paths.
///
/// Remaining risk: overlapping alternation such as `(a|a)*` or `(a|ab)*` is not detected and
/// can still backtrack exponentially. Hosts that accept untrusted specs should also keep
/// validation off the typing path (validate on blur or submit).
public enum PatternGuard {
    public static let maxPatternLength = 256
    public static let maxValueLength = 4_096

    /// Why a `pattern` check was refused.
    public enum Refusal: String, Sendable, Hashable {
        case patternTooLong, valueTooLong, nestedQuantifier
    }

    /// The refusal for this pattern and value, or `nil` when the check may run.
    public static func refusal(pattern: String, value: String) -> Refusal? {
        if pattern.utf16.count > maxPatternLength { return .patternTooLong }
        if value.utf16.count > maxValueLength { return .valueTooLong }
        if hasNestedQuantifier(pattern) { return .nestedQuantifier }
        return nil
    }

    /// `true` when a group whose body holds a quantifier is itself repeated more than once.
    /// Linear in the pattern length; never traps on malformed input.
    public static func hasNestedQuantifier(_ pattern: String) -> Bool {
        let chars = Array(pattern.unicodeScalars)
        // One flag per open group: does its body hold a quantifier?
        var groups: [Bool] = [false]
        var index = 0
        func markQuantified() { groups[groups.count - 1] = true }
        while index < chars.count {
            let char = chars[index]
            switch char {
            case "\\":
                index += 2
                continue
            case "[":
                index = classEnd(chars, from: index)
                continue
            case "(":
                groups.append(false)
                index += 1
                // `(?:`, `(?=`, `(?<name>`: the `?` here is not a quantifier.
                if index < chars.count, chars[index] == "?" { index += 1 }
                continue
            case ")":
                let bodyQuantified = groups.count > 1 ? groups.removeLast() : false
                index += 1
                let (length, repeats) = quantifier(chars, at: index)
                if length > 0 {
                    if bodyQuantified && repeats { return true }
                    markQuantified()
                    index += length
                } else if bodyQuantified {
                    markQuantified()
                }
                continue
            default:
                let (length, _) = quantifier(chars, at: index)
                if length > 0 {
                    markQuantified()
                    index += length
                    continue
                }
                index += 1
            }
        }
        return false
    }

    /// The index after the `]` that closes the class opened at `start` (or the end).
    private static func classEnd(_ chars: [Unicode.Scalar], from start: Int) -> Int {
        var index = start + 1
        if index < chars.count, chars[index] == "^" { index += 1 }
        if index < chars.count, chars[index] == "]" { index += 1 }  // a leading `]` is literal
        while index < chars.count {
            if chars[index] == "\\" {
                index += 2
                continue
            }
            if chars[index] == "]" { return index + 1 }
            index += 1
        }
        return chars.count
    }

    /// The length of the quantifier at `index` (0 when there is none, a trailing lazy or
    /// possessive mark included) and whether it can repeat more than once.
    private static func quantifier(_ chars: [Unicode.Scalar], at index: Int) -> (Int, Bool) {
        guard index < chars.count else { return (0, false) }
        var length = 0
        var repeats = false
        switch chars[index] {
        case "*", "+":
            length = 1
            repeats = true
        case "?":
            length = 1
        case "{":
            guard let (braceLength, maximum) = braces(chars, at: index) else { return (0, false) }
            length = braceLength
            repeats = maximum.map { $0 > 1 } ?? true
        default:
            return (0, false)
        }
        if index + length < chars.count,
            chars[index + length] == "?" || chars[index + length] == "+"
        {
            length += 1
        }
        return (length, repeats)
    }

    /// `{n}`, `{n,}`, `{n,m}` or `{,m}` at `index`: its length and its maximum (`nil` = unbounded).
    /// Swift `Regex` reads `{,m}` as `0...m` (JavaScript reads it as literal text), so the guard must too.
    private static func braces(_ chars: [Unicode.Scalar], at index: Int) -> (Int, Int?)? {
        var cursor = index + 1
        func digits() -> Int? {
            let start = cursor
            var value = 0
            while cursor < chars.count, let digit = Int(String(chars[cursor])), cursor - start < 9 {
                value = value * 10 + digit
                cursor += 1
            }
            return cursor > start ? value : nil
        }
        let leading = digits()
        var maximum: Int? = leading
        var hasComma = false
        if cursor < chars.count, chars[cursor] == "," {
            hasComma = true
            cursor += 1
            maximum = digits()
        }
        // A bare `{}` or `{,}` is literal text, not a quantifier.
        guard leading != nil || (hasComma && maximum != nil) else { return nil }
        guard cursor < chars.count, chars[cursor] == "}" else { return nil }
        return (cursor + 1 - index, maximum)
    }
}
