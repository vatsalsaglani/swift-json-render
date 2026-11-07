// Owner: jr-2 (wave 2).

/// A best-effort JSON parser for a document that is still arriving.
///
/// At the end of the input it closes an open string, then every open array and object. It
/// drops a trailing partial token: a cut literal (`tru`, `nul`), any number that touches the
/// end (`12` may still become `123`), a cut escape (`"a\`, `"\u00`), a key with no value, and
/// a trailing comma. It cannot recover from bytes that are not JSON (it returns no value) and
/// it refuses nesting deeper than `JSONValue.maxDecodeDepth`.
///
/// `cutPath` is the path of the innermost value the end of input cut, or `nil` when the
/// document is complete. A value is complete exactly when its path is not a prefix of
/// `cutPath`.
enum TolerantJSON {
    struct Result: Sendable, Hashable {
        var value: JSONValue?
        var cutPath: [String]?
    }

    static func parse(_ bytes: ArraySlice<UInt8>) -> Result {
        var parser = Parser(bytes: bytes)
        let outcome = parser.parseValue(depth: 0, path: [])
        switch outcome {
        case .complete(let value):
            parser.skipWhitespace()
            guard parser.atEnd else { return Result(value: nil, cutPath: nil) }
            return Result(value: value, cutPath: nil)
        case .cut(let value):
            return Result(value: value, cutPath: parser.cutPath ?? [])
        case .invalid:
            return Result(value: nil, cutPath: nil)
        }
    }

    /// The length of the longest prefix that does not end inside a UTF-8 scalar.
    static func completeUTF8Prefix(_ bytes: [UInt8]) -> Int {
        var start = bytes.count
        var lookedAt = 0
        while start > 0, lookedAt < 4 {
            start -= 1
            lookedAt += 1
            let byte = bytes[start]
            if byte & 0b1100_0000 == 0b1000_0000 { continue }  // continuation byte
            let length: Int
            if byte & 0b1000_0000 == 0 {
                length = 1
            } else if byte & 0b1110_0000 == 0b1100_0000 {
                length = 2
            } else if byte & 0b1111_0000 == 0b1110_0000 {
                length = 3
            } else if byte & 0b1111_1000 == 0b1111_0000 {
                length = 4
            } else {
                return bytes.count  // not UTF-8; let the parser decide
            }
            return bytes.count - start >= length ? bytes.count : start
        }
        return bytes.count
    }

    static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == 0x20 || byte == 0x0A || byte == 0x0D || byte == 0x09
    }

    private enum Outcome {
        case complete(JSONValue)
        /// The input ended inside this value; the payload is the best effort, if any.
        case cut(JSONValue?)
        case invalid
    }

    private struct Parser {
        let bytes: ArraySlice<UInt8>
        var index: ArraySlice<UInt8>.Index
        var cutPath: [String]?

        init(bytes: ArraySlice<UInt8>) {
            self.bytes = bytes
            index = bytes.startIndex
        }

        var atEnd: Bool { index >= bytes.endIndex }

        mutating func skipWhitespace() {
            while index < bytes.endIndex, TolerantJSON.isWhitespace(bytes[index]) {
                index += 1
            }
        }

        private mutating func cut(_ value: JSONValue?, at path: [String]) -> Outcome {
            if cutPath == nil { cutPath = path }
            return .cut(value)
        }

        mutating func parseValue(depth: Int, path: [String]) -> Outcome {
            skipWhitespace()
            guard index < bytes.endIndex else { return cut(nil, at: path) }
            switch bytes[index] {
            case UInt8(ascii: "{"):
                return parseObject(depth: depth + 1, path: path)
            case UInt8(ascii: "["):
                return parseArray(depth: depth + 1, path: path)
            case UInt8(ascii: "\""):
                switch parseString() {
                case .some(.complete(let text)): return .complete(.string(text))
                case .some(.cut(let text)): return cut(.string(text), at: path)
                case nil: return .invalid
                }
            case UInt8(ascii: "t"): return parseLiteral("true", .bool(true), path: path)
            case UInt8(ascii: "f"): return parseLiteral("false", .bool(false), path: path)
            case UInt8(ascii: "n"): return parseLiteral("null", .null, path: path)
            case UInt8(ascii: "-"), UInt8(ascii: "0")...UInt8(ascii: "9"):
                return parseNumber(path: path)
            default:
                return .invalid
            }
        }

        private mutating func parseObject(depth: Int, path: [String]) -> Outcome {
            guard depth <= JSONValue.maxDecodeDepth else { return .invalid }
            index += 1
            var members: [String: JSONValue] = [:]
            while true {
                skipWhitespace()
                guard index < bytes.endIndex else { return cut(.object(members), at: path) }
                if bytes[index] == UInt8(ascii: "}") {
                    index += 1
                    return .complete(.object(members))
                }
                guard bytes[index] == UInt8(ascii: "\"") else { return .invalid }
                let key: String
                switch parseString() {
                case .some(.complete(let text)): key = text
                case .some(.cut): return cut(.object(members), at: path)
                case nil: return .invalid
                }
                skipWhitespace()
                guard index < bytes.endIndex else { return cut(.object(members), at: path + [key]) }
                guard bytes[index] == UInt8(ascii: ":") else { return .invalid }
                index += 1
                switch parseValue(depth: depth, path: path + [key]) {
                case .complete(let value):
                    members[key] = value
                case .cut(let value):
                    if let value { members[key] = value }
                    return .cut(.object(members))
                case .invalid:
                    return .invalid
                }
                skipWhitespace()
                guard index < bytes.endIndex else { return cut(.object(members), at: path) }
                switch bytes[index] {
                case UInt8(ascii: ","): index += 1
                case UInt8(ascii: "}"):
                    index += 1
                    return .complete(.object(members))
                default: return .invalid
                }
            }
        }

        private mutating func parseArray(depth: Int, path: [String]) -> Outcome {
            guard depth <= JSONValue.maxDecodeDepth else { return .invalid }
            index += 1
            var items: [JSONValue] = []
            while true {
                skipWhitespace()
                guard index < bytes.endIndex else { return cut(.array(items), at: path) }
                if bytes[index] == UInt8(ascii: "]") {
                    index += 1
                    return .complete(.array(items))
                }
                switch parseValue(depth: depth, path: path + [String(items.count)]) {
                case .complete(let value):
                    items.append(value)
                case .cut(let value):
                    if let value { items.append(value) }
                    return .cut(.array(items))
                case .invalid:
                    return .invalid
                }
                skipWhitespace()
                guard index < bytes.endIndex else { return cut(.array(items), at: path) }
                switch bytes[index] {
                case UInt8(ascii: ","): index += 1
                case UInt8(ascii: "]"):
                    index += 1
                    return .complete(.array(items))
                default: return .invalid
                }
            }
        }

        private enum StringOutcome {
            case complete(String)
            case cut(String)
        }

        /// Parses a string at `index` (on the opening quote). `nil` for an invalid escape or a
        /// raw control character.
        private mutating func parseString() -> StringOutcome? {
            index += 1
            var utf8: [UInt8] = []
            var pendingHigh: UInt32?
            func flushHigh() {
                if pendingHigh != nil {
                    utf8.append(contentsOf: [0xEF, 0xBF, 0xBD])  // U+FFFD for a lone surrogate
                    pendingHigh = nil
                }
            }
            func append(_ scalar: Unicode.Scalar) {
                utf8.append(contentsOf: Array(String(Character(scalar)).utf8))
            }
            while index < bytes.endIndex {
                let byte = bytes[index]
                switch byte {
                case UInt8(ascii: "\""):
                    flushHigh()
                    index += 1
                    return .complete(String(decoding: utf8, as: UTF8.self))
                case UInt8(ascii: "\\"):
                    guard index + 1 < bytes.endIndex else {
                        index = bytes.endIndex
                        return .cut(String(decoding: utf8, as: UTF8.self))
                    }
                    let escape = bytes[index + 1]
                    if escape == UInt8(ascii: "u") {
                        guard index + 6 <= bytes.endIndex else {
                            index = bytes.endIndex
                            return .cut(String(decoding: utf8, as: UTF8.self))
                        }
                        guard
                            let code = UInt32(
                                String(decoding: bytes[(index + 2)..<(index + 6)], as: UTF8.self),
                                radix: 16)
                        else {
                            return nil
                        }
                        index += 6
                        if (0xD800...0xDBFF).contains(code) {
                            flushHigh()
                            pendingHigh = code
                        } else if (0xDC00...0xDFFF).contains(code) {
                            if let high = pendingHigh {
                                let combined = 0x10000 + ((high - 0xD800) << 10) + (code - 0xDC00)
                                pendingHigh = nil
                                if let scalar = Unicode.Scalar(combined) { append(scalar) }
                            } else {
                                utf8.append(contentsOf: [0xEF, 0xBF, 0xBD])
                            }
                        } else {
                            flushHigh()
                            if let scalar = Unicode.Scalar(code) { append(scalar) }
                        }
                        continue
                    }
                    flushHigh()
                    switch escape {
                    case UInt8(ascii: "\""): utf8.append(0x22)
                    case UInt8(ascii: "\\"): utf8.append(0x5C)
                    case UInt8(ascii: "/"): utf8.append(0x2F)
                    case UInt8(ascii: "b"): utf8.append(0x08)
                    case UInt8(ascii: "f"): utf8.append(0x0C)
                    case UInt8(ascii: "n"): utf8.append(0x0A)
                    case UInt8(ascii: "r"): utf8.append(0x0D)
                    case UInt8(ascii: "t"): utf8.append(0x09)
                    default: return nil
                    }
                    index += 2
                default:
                    if byte < 0x20 { return nil }
                    flushHigh()
                    utf8.append(byte)
                    index += 1
                }
            }
            // A high surrogate waiting for its pair is a partial token: drop it.
            return .cut(String(decoding: utf8, as: UTF8.self))
        }

        private mutating func parseLiteral(_ word: String, _ value: JSONValue, path: [String])
            -> Outcome
        {
            for expected in word.utf8 {
                guard index < bytes.endIndex else { return cut(nil, at: path) }
                guard bytes[index] == expected else { return .invalid }
                index += 1
            }
            return .complete(value)
        }

        /// JSON number grammar. A number that reaches the end of input is dropped (it may
        /// still grow).
        private mutating func parseNumber(path: [String]) -> Outcome {
            let start = index
            while index < bytes.endIndex {
                switch bytes[index] {
                case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "+"),
                    UInt8(ascii: "."), UInt8(ascii: "e"), UInt8(ascii: "E"):
                    index += 1
                default:
                    let text = String(decoding: bytes[start..<index], as: UTF8.self)
                    guard TolerantJSON.isJSONNumber(text), let number = Double(text) else {
                        return .invalid
                    }
                    return .complete(.number(number))
                }
            }
            return cut(nil, at: path)
        }
    }

    /// `-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?`
    static func isJSONNumber(_ text: String) -> Bool {
        var bytes = Substring(text).utf8[...]
        func digits() -> Int {
            let count = bytes.prefix(while: { $0 >= 0x30 && $0 <= 0x39 }).count
            bytes = bytes.dropFirst(count)
            return count
        }
        if bytes.first == UInt8(ascii: "-") { bytes = bytes.dropFirst() }
        if bytes.first == UInt8(ascii: "0") {
            bytes = bytes.dropFirst()
        } else if digits() == 0 {
            return false
        }
        if bytes.first == UInt8(ascii: ".") {
            bytes = bytes.dropFirst()
            if digits() == 0 { return false }
        }
        if bytes.first == UInt8(ascii: "e") || bytes.first == UInt8(ascii: "E") {
            bytes = bytes.dropFirst()
            if bytes.first == UInt8(ascii: "+") || bytes.first == UInt8(ascii: "-") {
                bytes = bytes.dropFirst()
            }
            if digits() == 0 { return false }
        }
        return bytes.isEmpty
    }
}
