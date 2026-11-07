/// An upstream `VisibilityCondition` (`visibility.ts`, `types.ts`).
///
/// Parsing never fails: a shape the runtime cannot evaluate becomes `.invalid` (hidden), so
/// a spec with a bad `visible` still decodes and the spec validator can report
/// `invalid_visible`. Encoding is lossless: it writes back the decoded JSON.
public indirect enum VisibilityCondition: Sendable, Hashable {
    /// `true` or `false`.
    case always(Bool)
    /// One `$state`, `$item` or `$index` condition.
    case single(SingleCondition)
    /// A bare array: implicit AND.
    case all([VisibilityCondition])
    /// `{ "$and": [...] }`.
    case and([VisibilityCondition])
    /// `{ "$or": [...] }`.
    case or([VisibilityCondition])
    /// A value with no condition shape (for example `null`, a string, or an object without
    /// `$state`, `$item`, `$index`, `$and` or `$or`). Evaluates to hidden. Swift deviation:
    /// upstream evaluates some of these shapes by accident (for example `{}` reads the whole
    /// state and is visible) or throws.
    case invalid(JSONValue)
}

/// A warning from parsing a visibility condition.
public enum VisibilityParseWarning: Sendable, Hashable {
    /// Several comparison operators were present. Upstream precedence
    /// (`eq > neq > gt > gte > lt > lte`) kept one; the others have no effect.
    case extraOperators(kept: String, ignored: [String])
}

/// One condition: a subject, an optional comparison, and `not`.
public struct SingleCondition: Sendable, Hashable {
    /// What the condition reads.
    public enum Subject: Sendable, Hashable {
        /// `{ "$state": "/path" }`.
        case state(JSONPointer)
        /// `{ "$item": "field" }`; `""` is the whole item.
        case item(String)
        /// `{ "$index": true }`.
        case index
    }

    /// The comparison. Without one, the condition tests truthiness.
    public enum Comparison: Sendable, Hashable {
        /// `===` against a literal or a `{ "$state": "/p" }` operand (kept raw).
        case eq(JSONValue)
        /// `!==` against a literal or a `{ "$state": "/p" }` operand (kept raw).
        case neq(JSONValue)
        case gt(Operand)
        case gte(Operand)
        case lt(Operand)
        case lte(Operand)
    }

    /// The right side of a numeric comparison.
    public enum Operand: Sendable, Hashable {
        case number(Double)
        case state(JSONPointer)
        /// Neither a number nor a `$state` reference. The comparison is always `false`, as
        /// upstream (which compares only when both sides are numbers).
        case other(JSONValue)
    }

    public let subject: Subject
    public let comparison: Comparison?
    /// `not: true` inverts the whole result.
    public let not: Bool
    /// The decoded JSON object. Encoding writes it back unchanged, so keys this type does
    /// not model (a second subject, extra operators) survive a round trip and stay visible
    /// to strict validation.
    public let source: JSONValue

    public init(subject: Subject, comparison: Comparison? = nil, not: Bool = false) {
        self.subject = subject
        self.comparison = comparison
        self.not = not
        var members: [String: JSONValue] = [:]
        switch subject {
        case .state(let pointer): members["$state"] = .string(pointer.description)
        case .item(let field): members["$item"] = .string(field)
        case .index: members["$index"] = .bool(true)
        }
        if let comparison {
            let (key, value) = SingleCondition.encode(comparison)
            members[key] = value
        }
        if not { members["not"] = .bool(true) }
        self.source = .object(members)
    }

    init(subject: Subject, comparison: Comparison?, not: Bool, source: JSONValue) {
        self.subject = subject
        self.comparison = comparison
        self.not = not
        self.source = source
    }

    private static func encode(_ comparison: Comparison) -> (String, JSONValue) {
        switch comparison {
        case .eq(let value): ("eq", value)
        case .neq(let value): ("neq", value)
        case .gt(let operand): ("gt", operand.jsonValue)
        case .gte(let operand): ("gte", operand.jsonValue)
        case .lt(let operand): ("lt", operand.jsonValue)
        case .lte(let operand): ("lte", operand.jsonValue)
        }
    }
}

extension SingleCondition.Operand {
    var jsonValue: JSONValue {
        switch self {
        case .number(let value): .number(value)
        case .state(let pointer): .object(["$state": .string(pointer.description)])
        case .other(let value): value
        }
    }

    init(_ value: JSONValue) {
        switch value {
        case .number(let number):
            self = .number(number)
        case .object(let members):
            if case .string(let path)? = members["$state"] {
                self = .state(JSONPointer(lenient: path))
            } else {
                self = .other(value)
            }
        default:
            self = .other(value)
        }
    }
}

// MARK: - Parsing and encoding

extension VisibilityCondition {
    static let operatorPrecedence = ["eq", "neq", "gt", "gte", "lt", "lte"]

    /// Parses an upstream condition. Never fails; see `.invalid`.
    public static func parse(_ value: JSONValue) -> (
        condition: VisibilityCondition, warnings: [VisibilityParseWarning]
    ) {
        var warnings: [VisibilityParseWarning] = []
        let condition = parse(value, warnings: &warnings)
        return (condition, warnings)
    }

    /// Parses and drops the warnings.
    public init(json value: JSONValue) {
        self = VisibilityCondition.parse(value).condition
    }

    private static func parse(_ value: JSONValue, warnings: inout [VisibilityParseWarning])
        -> VisibilityCondition
    {
        switch value {
        case .bool(let flag):
            return .always(flag)
        case .array(let items):
            return .all(items.map { parse($0, warnings: &warnings) })
        case .object(let members):
            // Upstream checks `$and` before `$or`, both before a single condition.
            if let inner = members["$and"] {
                guard case .array(let items) = inner else { return .invalid(value) }
                return .and(items.map { parse($0, warnings: &warnings) })
            }
            if let inner = members["$or"] {
                guard case .array(let items) = inner else { return .invalid(value) }
                return .or(items.map { parse($0, warnings: &warnings) })
            }
            guard let single = parseSingle(members, source: value, warnings: &warnings) else {
                return .invalid(value)
            }
            return .single(single)
        default:
            return .invalid(value)
        }
    }

    private static func parseSingle(
        _ members: [String: JSONValue], source: JSONValue,
        warnings: inout [VisibilityParseWarning]
    ) -> SingleCondition? {
        // Upstream subject order: `"$index" in cond`, then `"$item" in cond`, then `$state`.
        let subject: SingleCondition.Subject
        if members["$index"] != nil {
            subject = .index
        } else if let item = members["$item"] {
            guard case .string(let field) = item else { return nil }
            subject = .item(field)
        } else if let state = members["$state"] {
            guard case .string(let path) = state else { return nil }
            subject = .state(JSONPointer(lenient: path))
        } else {
            return nil
        }
        let present = operatorPrecedence.filter { members[$0] != nil }
        var comparison: SingleCondition.Comparison?
        if let kept = present.first, let operand = members[kept] {
            switch kept {
            case "eq": comparison = .eq(operand)
            case "neq": comparison = .neq(operand)
            case "gt": comparison = .gt(SingleCondition.Operand(operand))
            case "gte": comparison = .gte(SingleCondition.Operand(operand))
            case "lt": comparison = .lt(SingleCondition.Operand(operand))
            default: comparison = .lte(SingleCondition.Operand(operand))
            }
            if present.count > 1 {
                warnings.append(.extraOperators(kept: kept, ignored: Array(present.dropFirst())))
            }
        }
        let not = members["not"] == .bool(true)
        return SingleCondition(subject: subject, comparison: comparison, not: not, source: source)
    }

    /// The JSON form. Lossless for parsed conditions.
    public var jsonValue: JSONValue {
        switch self {
        case .always(let flag): .bool(flag)
        case .single(let single): single.source
        case .all(let items): .array(items.map(\.jsonValue))
        case .and(let items): .object(["$and": .array(items.map(\.jsonValue))])
        case .or(let items): .object(["$or": .array(items.map(\.jsonValue))])
        case .invalid(let raw): raw
        }
    }
}

extension VisibilityCondition: Codable {
    public init(from decoder: any Decoder) throws {
        self.init(json: try JSONValue(from: decoder))
    }

    public func encode(to encoder: any Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

// MARK: - Repeat scope helpers

extension VisibilityCondition {
    /// Upstream `conditionUsesItemScope`: `true` when `$item` or `$index` appears anywhere.
    public var usesItemScope: Bool {
        switch self {
        case .always: false
        case .single(let single): single.usesItemScope
        case .all(let items), .and(let items), .or(let items): items.contains { $0.usesItemScope }
        case .invalid(let raw): VisibilityCondition.rawUsesItemScope(raw)
        }
    }

    private static func rawUsesItemScope(_ raw: JSONValue) -> Bool {
        switch raw {
        case .array(let items): items.contains(where: rawUsesItemScope)
        case .object(let members): members["$item"] != nil || members["$index"] != nil
        default: false
        }
    }

    /// Upstream `splitRepeatVisibility`: splits a repeat container's condition into a
    /// container gate and a per-item filter. Top-level AND forms partition by conjunct; a
    /// single item condition or an `$or` that mixes scopes becomes the item filter entirely.
    public func splitForRepeat() -> (
        container: VisibilityCondition?, itemFilter: VisibilityCondition?
    ) {
        guard usesItemScope else { return (self, nil) }
        func partition(_ parts: [VisibilityCondition]) -> (
            VisibilityCondition?, VisibilityCondition?
        ) {
            let container = parts.filter { !$0.usesItemScope }
            let item = parts.filter(\.usesItemScope)
            return (
                container.isEmpty ? nil : .and(container),
                item.isEmpty ? nil : .and(item)
            )
        }
        switch self {
        case .all(let parts), .and(let parts): return partition(parts)
        default: return (nil, self)
        }
    }

    /// Upstream `splitRepeatVisibility` for an optional condition.
    public static func splitForRepeat(_ condition: VisibilityCondition?) -> (
        container: VisibilityCondition?, itemFilter: VisibilityCondition?
    ) {
        guard let condition else { return (nil, nil) }
        return condition.splitForRepeat()
    }
}

extension SingleCondition {
    var usesItemScope: Bool {
        switch subject {
        case .item, .index: true
        case .state: false
        }
    }
}

// MARK: - Strict validation

extension VisibilityCondition {
    /// Upstream `VisibilityConditionStrictSchema`: `true` only for the documented forms with
    /// no unknown keys (for example, mixing `$state` and `$item` in one object fails). The
    /// spec validator reports `invalid_visible` when this is `false`.
    public var isStrictlyValid: Bool {
        VisibilityCondition.isStrictlyValid(jsonValue)
    }

    /// Strict validation of a raw JSON condition.
    public static func isStrictlyValid(_ value: JSONValue) -> Bool {
        switch value {
        case .bool:
            return true
        case .array(let items):
            return items.allSatisfy(isStrictSingle)
        case .object(let members):
            if members.count == 1, let inner = members["$and"] ?? members["$or"] {
                guard case .array(let items) = inner else { return false }
                return items.allSatisfy(isStrictlyValid)
            }
            return isStrictSingle(value)
        default:
            return false
        }
    }

    private static let comparisonKeys: Set<String> = ["eq", "neq", "gt", "gte", "lt", "lte", "not"]

    private static func isStrictSingle(_ value: JSONValue) -> Bool {
        guard case .object(let members) = value else { return false }
        let subjects = members.keys.filter { $0 == "$state" || $0 == "$item" || $0 == "$index" }
        guard subjects.count == 1, let subjectKey = subjects.first else { return false }
        switch (subjectKey, members[subjectKey]) {
        case ("$state", .string?), ("$item", .string?), ("$index", .bool(true)?): break
        default: return false
        }
        for (key, operand) in members where key != subjectKey {
            guard comparisonKeys.contains(key) else { return false }
            switch key {
            case "not":
                guard operand == .bool(true) else { return false }
            case "gt", "gte", "lt", "lte":
                switch operand {
                case .number: break
                case .object(let reference):
                    guard case .string? = reference["$state"] else { return false }
                default: return false
                }
            default:
                break  // eq / neq accept any value
            }
        }
        return true
    }
}
