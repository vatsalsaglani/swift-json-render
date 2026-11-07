/// The four upstream path operations from `types.ts`, with the same semantics.
///
/// - Reads (`getByPath`) index arrays with JavaScript `parseInt` and return `nil` when the
///   path is absent or crosses a non-container.
/// - Writes (`setByPath`, `addByPath`) create missing intermediates: an array when the next
///   token is a decimal index or `"-"`, otherwise an object. `"-"` appends. An index above
///   the array count is refused, so a write never leaves a hole. Intermediates created before
///   a refused final step stay, as upstream (which mutates in place).
/// - The root pointer and any pointer with `__proto__` are refused by every write and
///   resolve to `nil` on read.
/// - Writes and removals refuse a pointer with more than `JSONValue.maxDecodeDepth` tokens
///   (they recurse once per token). Reads are iterative and accept any length.
extension JSONValue {
    /// Upstream `getByPath`.
    public func value(at pointer: JSONPointer) -> JSONValue? {
        if pointer.containsForbiddenToken { return nil }
        var current = self
        for token in pointer.tokens {
            switch current {
            case .array(let items):
                guard let index = PathIndex.parseInt(token), items.indices.contains(index) else {
                    return nil
                }
                current = items[index]
            case .object(let members):
                guard let next = members[token] else { return nil }
                current = next
            default:
                return nil
            }
        }
        return current
    }

    /// Upstream `setByPath`: replaces an array element in place.
    @discardableResult
    public mutating func set(_ value: JSONValue, at pointer: JSONPointer) -> Bool {
        guard JSONValue.isWritable(pointer) else { return false }
        return JSONValue.write(&self, pointer.tokens[...], value, insert: false)
    }

    /// Upstream `addByPath` (RFC 6902 `add`): inserts into arrays.
    @discardableResult
    public mutating func add(_ value: JSONValue, at pointer: JSONPointer) -> Bool {
        guard JSONValue.isWritable(pointer) else { return false }
        return JSONValue.write(&self, pointer.tokens[...], value, insert: true)
    }

    /// Upstream `removeByPath`: a no-op (returning `false`) when the path is absent.
    @discardableResult
    public mutating func remove(at pointer: JSONPointer) -> Bool {
        guard JSONValue.isWritable(pointer) else { return false }
        return JSONValue.removeValue(&self, pointer.tokens[...])
    }

    /// The RFC 6902 `test` operation: deep equality of the value at `pointer` with `value`.
    public func test(_ value: JSONValue, at pointer: JSONPointer) -> Bool {
        self.value(at: pointer) == value
    }

    // MARK: - Implementation

    /// Not the root, no `__proto__`, and not deeper than `maxDecodeDepth` tokens.
    static func isWritable(_ pointer: JSONPointer) -> Bool {
        !pointer.isRoot && !pointer.containsForbiddenToken
            && pointer.tokens.count <= maxDecodeDepth
    }

    private static func emptyContainer(before nextToken: String) -> JSONValue {
        PathIndex.isNumeric(nextToken) || nextToken == "-" ? .array([]) : .object([:])
    }

    private static func write(
        _ node: inout JSONValue, _ tokens: ArraySlice<String>, _ value: JSONValue, insert: Bool
    ) -> Bool {
        guard let token = tokens.first else { return false }
        let rest = tokens.dropFirst()
        switch node {
        case .array(var items):
            node = .null  // keep `items` uniquely referenced while it changes
            defer { node = .array(items) }
            if rest.isEmpty {
                if token == "-" {
                    items.append(value)
                    return true
                }
                guard let index = PathIndex.dense(token, count: items.count) else { return false }
                if insert || index == items.count {
                    items.insert(value, at: index)
                } else {
                    items[index] = value
                }
                return true
            }
            guard let index = PathIndex.dense(token, count: items.count),
                let next = rest.first
            else { return false }
            if index == items.count {
                items.append(emptyContainer(before: next))
            } else if !items[index].isContainer {
                items[index] = emptyContainer(before: next)
            }
            return write(&items[index], rest, value, insert: insert)
        case .object(var members):
            node = .null
            defer { node = .object(members) }
            if rest.isEmpty {
                members[token] = value
                return true
            }
            guard let next = rest.first else { return false }
            if members[token]?.isContainer != true {
                members[token] = emptyContainer(before: next)
            }
            return write(&members[token]!, rest, value, insert: insert)
        default:
            return false
        }
    }

    private static func removeValue(_ node: inout JSONValue, _ tokens: ArraySlice<String>) -> Bool {
        guard let token = tokens.first else { return false }
        let rest = tokens.dropFirst()
        switch node {
        case .array(var items):
            guard let index = PathIndex.parseInt(token), items.indices.contains(index) else {
                return false
            }
            if !rest.isEmpty && !items[index].isContainer { return false }
            node = .null
            defer { node = .array(items) }
            if rest.isEmpty {
                items.remove(at: index)
                return true
            }
            return removeValue(&items[index], rest)
        case .object(var members):
            guard let child = members[token] else { return false }
            if !rest.isEmpty && !child.isContainer { return false }
            node = .null
            defer { node = .object(members) }
            if rest.isEmpty {
                members.removeValue(forKey: token)
                return true
            }
            return removeValue(&members[token]!, rest)
        default:
            return false
        }
    }
}

/// Upstream index helpers: `isNumericIndex`, `denseIndex` and JavaScript `parseInt`.
enum PathIndex {
    /// `/^\d+$/`.
    static func isNumeric(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.allSatisfy { $0 >= 0x30 && $0 <= 0x39 }
    }

    /// The index `token` names when it is decimal and not above `count`.
    static func dense(_ token: String, count: Int) -> Int? {
        guard isNumeric(token), let index = Int(token), index <= count else { return nil }
        return index
    }

    /// JavaScript `parseInt(token, 10)`: leading white space, an optional sign, then the
    /// longest run of decimal digits. `nil` for `NaN` or a value that does not fit `Int`.
    static func parseInt(_ token: String) -> Int? {
        var scalars = Substring(token).drop(while: { $0.isWhitespace })
        var negative = false
        if let first = scalars.first, first == "-" || first == "+" {
            negative = first == "-"
            scalars = scalars.dropFirst()
        }
        let digits = scalars.prefix(while: { $0.isASCII && $0.isNumber })
        guard !digits.isEmpty, let magnitude = Int(digits) else { return nil }
        return negative ? -magnitude : magnitude
    }
}
