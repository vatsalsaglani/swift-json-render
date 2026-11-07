/// A prop value with its expressions recognised (upstream `props.ts`).
///
/// Recognition follows the upstream type guards exactly and in the same order:
/// `$state`, `$item`, `$index`, `$bindState`, `$bindItem`, `$cond`, `$computed`, `$template`,
/// then arrays, then custom directives, then plain objects. A key with the wrong value type
/// (for example `{ "$state": 5 }`) is not an expression; the object is a plain object.
public indirect enum PropExpression: Sendable, Hashable {
    /// A scalar literal (`null`, Boolean, number or string).
    case literal(JSONValue)
    /// `{ "$state": "/p" }`.
    case state(JSONPointer)
    /// `{ "$bindState": "/p" }`: reads like `$state` and exposes the path for write-back.
    case bindState(JSONPointer)
    /// `{ "$item": "field" }`; `""` is the whole item.
    case item(String)
    /// `{ "$bindItem": "field" }`: reads the repeat item field through state and exposes
    /// the absolute path for write-back.
    case bindItem(String)
    /// `{ "$index": true }`.
    case index
    /// `{ "$cond": …, "$then": …, "$else": … }`.
    case cond(VisibilityCondition, then: PropExpression, else: PropExpression)
    /// `{ "$computed": "name", "args": { … } }`: calls a registered function.
    case computed(String, args: [String: PropExpression])
    /// `{ "$template": "Hello ${/user/name}" }`.
    case template(String)
    /// A registered custom directive, with the whole raw object.
    case directive(name: String, raw: JSONValue)
    case array([PropExpression])
    case object([String: PropExpression])

    /// Upstream `BUILT_IN_KEYS`; directives must not use them.
    public static let builtInKeys: Set<String> = [
        "$state", "$item", "$index", "$bindState", "$bindItem", "$cond", "$computed", "$template",
    ]

    /// Parses a raw prop value. Built-in keys win over directives. An object with two
    /// directive keys throws `.ambiguousDirective` (names in sorted order).
    public static func parse(_ value: JSONValue, directiveNames: Set<String> = [])
        throws(PropExpressionError) -> PropExpression
    {
        try parse(value, orderedDirectives: directiveNames.sorted())
    }

    /// Parses with the directive names in registry order (for upstream error order).
    static func parse(_ value: JSONValue, orderedDirectives: [String]) throws(PropExpressionError)
        -> PropExpression
    {
        switch value {
        case .array(let items):
            var parsed: [PropExpression] = []
            parsed.reserveCapacity(items.count)
            for item in items {
                parsed.append(try parse(item, orderedDirectives: orderedDirectives))
            }
            return .array(parsed)
        case .object(let members):
            return try parseObject(members, raw: value, orderedDirectives: orderedDirectives)
        default:
            return .literal(value)
        }
    }

    private static func parseObject(
        _ members: [String: JSONValue], raw: JSONValue, orderedDirectives: [String]
    ) throws(PropExpressionError) -> PropExpression {
        if case .string(let path)? = members["$state"] {
            return .state(JSONPointer(lenient: path))
        }
        if case .string(let field)? = members["$item"] {
            return .item(field)
        }
        if members["$index"] == .bool(true) {
            return .index
        }
        if case .string(let path)? = members["$bindState"] {
            return .bindState(JSONPointer(lenient: path))
        }
        if case .string(let field)? = members["$bindItem"] {
            return .bindItem(field)
        }
        if let condition = members["$cond"], let thenValue = members["$then"],
            let elseValue = members["$else"]
        {
            return .cond(
                VisibilityCondition(json: condition),
                then: try parse(thenValue, orderedDirectives: orderedDirectives),
                else: try parse(elseValue, orderedDirectives: orderedDirectives))
        }
        if case .string(let name)? = members["$computed"] {
            var args: [String: PropExpression] = [:]
            if case .object(let rawArgs)? = members["args"] {
                for (key, arg) in rawArgs {
                    args[key] = try parse(arg, orderedDirectives: orderedDirectives)
                }
            }
            return .computed(name, args: args)
        }
        if case .string(let template)? = members["$template"] {
            return .template(template)
        }
        var match: String?
        for name in orderedDirectives where members[name] != nil {
            if let first = match { throw .ambiguousDirective(first, name) }
            match = name
        }
        if let match {
            return .directive(name: match, raw: raw)
        }
        var parsed: [String: PropExpression] = [:]
        for (key, member) in members {
            parsed[key] = try parse(member, orderedDirectives: orderedDirectives)
        }
        return .object(parsed)
    }

    /// `true` for `$bindState` and `$bindItem`.
    public var isBinding: Bool {
        switch self {
        case .bindState, .bindItem: true
        default: false
        }
    }
}

/// Why a prop value could not be parsed.
public enum PropExpressionError: Error, Sendable, Equatable {
    /// Upstream: `Ambiguous directive: object has multiple directive keys ("a" and "b")`.
    case ambiguousDirective(String, String)
}
