/// An RFC 6901 JSON Pointer with upstream json-render leniency and guards.
///
/// - `""` and `"/"` are both the root (upstream `getByPath` treats both as the whole
///   document).
/// - A pointer without a leading slash is accepted: `"a/b"` is `"/a/b"` (upstream
///   `parseJsonPointer`).
/// - Tokens unescape `~1` to `/` first, then `~0` to `~`.
/// - The token `__proto__` is forbidden. The throwing initialiser refuses it; a pointer that
///   holds it anyway (built from tokens or a literal) is refused by every path operation.
public struct JSONPointer: Sendable, Hashable {
    /// The unescaped reference tokens. Empty for the root.
    public var tokens: [String]

    /// Parses `string`. Throws only for the forbidden token `__proto__`.
    ///
    /// Note: `JSONPointer("/literal")` with a string *literal* is literal coercion and calls
    /// `init(stringLiteral:)`, which never throws. Pass a `String` value to get the check.
    public init(_ string: String) throws(JSONPointerError) {
        self.init(lenient: string)
        if let forbidden = tokens.first(where: { $0 == JSONPointer.forbiddenToken }) {
            throw .forbiddenToken(forbidden)
        }
    }

    /// A pointer made of already-unescaped tokens.
    public init(tokens: [String]) {
        self.tokens = tokens
    }

    /// Parses without the forbidden-token check. Path operations still refuse the pointer.
    init(lenient string: String) {
        if string.isEmpty || string == "/" {
            tokens = []
            return
        }
        let body = string.hasPrefix("/") ? String(string.dropFirst()) : string
        tokens = body.split(separator: "/", omittingEmptySubsequences: false).map {
            JSONPointer.unescape(String($0))
        }
    }

    /// The root pointer.
    public static let root = JSONPointer(tokens: [])

    /// `true` for `""` and `"/"`.
    public var isRoot: Bool { tokens.isEmpty }

    /// `true` when any token is `__proto__` (upstream prototype-pollution guard).
    public var containsForbiddenToken: Bool {
        tokens.contains(JSONPointer.forbiddenToken)
    }

    /// A pointer one token deeper.
    public func appending(_ token: String) -> JSONPointer {
        JSONPointer(tokens: tokens + [token])
    }

    /// Upstream `joinStatePath`: strips one leading `/` from `relative`, then appends its
    /// tokens. An empty remainder returns `self`.
    public func appending(relative: String) -> JSONPointer {
        let child = relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        if child.isEmpty { return self }
        return JSONPointer(tokens: tokens + JSONPointer(lenient: "/" + child).tokens)
    }

    /// A pointer to the array element at `index`.
    public func appending(index: Int) -> JSONPointer {
        appending(String(index))
    }

    /// The parent pointer, or `nil` for the root.
    public var parent: JSONPointer? {
        guard !tokens.isEmpty else { return nil }
        return JSONPointer(tokens: Array(tokens.dropLast()))
    }

    static let forbiddenToken = "__proto__"

    static func unescape(_ token: String) -> String {
        guard token.contains("~") else { return token }
        return token.replacing("~1", with: "/").replacing("~0", with: "~")
    }

    static func escape(_ token: String) -> String {
        guard token.contains("~") || token.contains("/") else { return token }
        return token.replacing("~", with: "~0").replacing("/", with: "~1")
    }
}

/// Why a pointer string was refused.
public enum JSONPointerError: Error, Sendable, Equatable {
    /// The pointer names `__proto__`. Parity: upstream refuses such a pointer before any write.
    case forbiddenToken(String)
}

extension JSONPointer: CustomStringConvertible {
    /// The canonical form: `""` for the root, otherwise `"/a/b"` with `~0` and `~1` escaping.
    public var description: String {
        tokens.map { "/" + JSONPointer.escape($0) }.joined()
    }
}

extension JSONPointer: ExpressibleByStringLiteral {
    /// A literal never throws. A literal with `__proto__` gives a pointer that every path
    /// operation refuses.
    public init(stringLiteral value: String) {
        self.init(lenient: value)
    }
}

extension JSONPointer: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(lenient: try container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}
