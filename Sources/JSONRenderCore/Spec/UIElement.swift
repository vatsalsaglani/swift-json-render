/// One element of a flat spec (upstream `UIElement`).
public struct UIElement: Sendable, Hashable {
    /// The component type from the catalog.
    public var type: String
    /// The raw props. Values may hold expressions; resolve them with `PropResolver`.
    /// JSON `null` props are kept.
    public var props: [String: JSONValue]
    /// Child element ids.
    public var children: [String]?
    /// Named child regions.
    public var slots: [String: [String]]?
    public var visible: VisibilityCondition?
    /// Event name to action bindings. A single binding decodes as a one-element array;
    /// encoding always writes an array.
    public var on: [String: [ActionBinding]]?
    public var `repeat`: RepeatConfig?
    /// State path to action bindings, fired when the value at the path changes. Same
    /// normalisation as `on`.
    public var watch: [String: [ActionBinding]]?

    public init(
        type: String, props: [String: JSONValue] = [:], children: [String]? = nil,
        slots: [String: [String]]? = nil, visible: VisibilityCondition? = nil,
        on: [String: [ActionBinding]]? = nil, repeat: RepeatConfig? = nil,
        watch: [String: [ActionBinding]]? = nil
    ) {
        self.type = type
        self.props = props
        self.children = children
        self.slots = slots
        self.visible = visible
        self.on = on
        self.repeat = `repeat`
        self.watch = watch
    }

    /// The element keys this type models. Other keys are reported by `Spec.decode`.
    public static let knownKeys: Set<String> = [
        "type", "props", "children", "slots", "visible", "on", "repeat", "watch",
    ]
}

/// `repeat`: render the children once per element of a state array.
public struct RepeatConfig: Sendable, Hashable {
    public var statePath: RepeatStatePath
    /// The item field that identifies a row.
    public var key: String?

    public init(statePath: RepeatStatePath, key: String? = nil) {
        self.statePath = statePath
        self.key = key
    }
}

/// `"statePath": "/items"` or `"statePath": { "$item": "rows" }`. The raw string is kept;
/// resolve it with `RepeatScope.resolveStatePath(_:enclosing:)`.
public enum RepeatStatePath: Sendable, Hashable {
    case absolute(String)
    case item(String)
}

// MARK: - JSON conversion

extension UIElement {
    /// Builds an element from JSON. Unknown keys are ignored here (`Spec.decode` reports
    /// them). Throws `.shape` for a wrong type in a modelled key.
    public init(json: JSONValue, id: String = "") throws(SpecDecodeError) {
        var warnings: [SpecDecodeWarning] = []
        try self.init(json: json, id: id, warnings: &warnings)
    }

    init(json: JSONValue, id: String, warnings: inout [SpecDecodeWarning]) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("Element \"\(id)\" is not an object.")
        }
        guard case .string(let type)? = members["type"] else {
            throw .shape("Element \"\(id)\" has no string \"type\".")
        }
        self.type = type
        switch members["props"] {
        case nil, .null?: props = [:]
        case .object(let values)?: props = values
        default: throw .shape("Element \"\(id)\" has \"props\" that is not an object.")
        }
        children = try UIElement.stringList(members["children"], what: "children", id: id)
        if let rawSlots = members["slots"], rawSlots != .null {
            guard case .object(let slotMembers) = rawSlots else {
                throw .shape("Element \"\(id)\" has \"slots\" that is not an object.")
            }
            var slots: [String: [String]] = [:]
            for (name, value) in slotMembers {
                slots[name] = try UIElement.stringList(value, what: "slots.\(name)", id: id) ?? []
            }
            self.slots = slots
        } else {
            slots = nil
        }
        if let rawVisible = members["visible"] {
            let (condition, visibilityWarnings) = VisibilityCondition.parse(rawVisible)
            visible = condition
            for case .extraOperators(let kept, let ignored) in visibilityWarnings {
                warnings.append(
                    .extraVisibilityOperators(element: id, kept: kept, ignored: ignored))
            }
        } else {
            visible = nil
        }
        on = try UIElement.bindingMap(members["on"], field: "on", id: id, warnings: &warnings)
        watch = try UIElement.bindingMap(
            members["watch"], field: "watch", id: id, warnings: &warnings)
        if let rawRepeat = members["repeat"], rawRepeat != .null {
            self.repeat = try RepeatConfig(json: rawRepeat, id: id)
        } else {
            self.repeat = nil
        }
        for key in members.keys.sorted() where !UIElement.knownKeys.contains(key) {
            warnings.append(.unknownElementKey(element: id, key: key))
        }
    }

    /// The JSON form. `props` is always written; absent optional fields are omitted.
    public var jsonValue: JSONValue {
        var members: [String: JSONValue] = ["type": .string(type), "props": .object(props)]
        if let children { members["children"] = .array(children.map(JSONValue.string)) }
        if let slots {
            members["slots"] = .object(slots.mapValues { .array($0.map(JSONValue.string)) })
        }
        if let visible { members["visible"] = visible.jsonValue }
        if let on { members["on"] = UIElement.bindingMapJSON(on) }
        if let `repeat` { members["repeat"] = `repeat`.jsonValue }
        if let watch { members["watch"] = UIElement.bindingMapJSON(watch) }
        return .object(members)
    }

    private static func stringList(_ value: JSONValue?, what: String, id: String)
        throws(SpecDecodeError) -> [String]?
    {
        guard let value, value != .null else { return nil }
        guard case .array(let items) = value else {
            throw .shape("Element \"\(id)\" has \"\(what)\" that is not an array.")
        }
        var result: [String] = []
        result.reserveCapacity(items.count)
        for item in items {
            guard case .string(let string) = item else {
                throw .shape("Element \"\(id)\" has a non-string id in \"\(what)\".")
            }
            result.append(string)
        }
        return result
    }

    private static func bindingMap(
        _ value: JSONValue?, field: String, id: String, warnings: inout [SpecDecodeWarning]
    ) throws(SpecDecodeError) -> [String: [ActionBinding]]? {
        guard let value, value != .null else { return nil }
        guard case .object(let members) = value else {
            throw .shape("Element \"\(id)\" has \"\(field)\" that is not an object.")
        }
        var result: [String: [ActionBinding]] = [:]
        for (event, raw) in members {
            switch raw {
            case .array(let items):
                var bindings: [ActionBinding] = []
                for item in items { bindings.append(try ActionBinding(json: item)) }
                result[event] = bindings
            case .object:
                result[event] = [try ActionBinding(json: raw)]
                warnings.append(.singleBindingNormalised(element: id, event: event))
            default:
                throw .shape("Element \"\(id)\" has an invalid binding for \"\(field).\(event)\".")
            }
        }
        return result
    }

    private static func bindingMapJSON(_ map: [String: [ActionBinding]]) -> JSONValue {
        .object(map.mapValues { .array($0.map(\.jsonValue)) })
    }
}

extension RepeatConfig {
    init(json: JSONValue, id: String) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("Element \"\(id)\" has \"repeat\" that is not an object.")
        }
        switch members["statePath"] {
        case .string(let path)?:
            statePath = .absolute(path)
        case .object(let reference)?:
            guard case .string(let relative)? = reference["$item"] else {
                throw .shape("Element \"\(id)\" has an invalid \"repeat.statePath\".")
            }
            statePath = .item(relative)
        default:
            throw .shape("Element \"\(id)\" has an invalid \"repeat.statePath\".")
        }
        switch members["key"] {
        case nil, .null?: key = nil
        case .string(let field)?: key = field
        default: throw .shape("Element \"\(id)\" has a non-string \"repeat.key\".")
        }
    }

    var jsonValue: JSONValue {
        var members: [String: JSONValue] = [:]
        switch statePath {
        case .absolute(let path): members["statePath"] = .string(path)
        case .item(let relative): members["statePath"] = .object(["$item": .string(relative)])
        }
        if let key { members["key"] = .string(key) }
        return .object(members)
    }
}

extension UIElement: Codable {
    public init(from decoder: any Decoder) throws {
        let json = try JSONValue(from: decoder)
        do {
            try self.init(json: json)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: error.message))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

extension RepeatConfig: Codable {
    public init(from decoder: any Decoder) throws {
        let json = try JSONValue(from: decoder)
        do {
            try self.init(json: json, id: "")
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: error.message))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        try jsonValue.encode(to: encoder)
    }
}

extension RepeatStatePath: Codable {
    public init(from decoder: any Decoder) throws {
        let json = try JSONValue(from: decoder)
        if case .string(let path) = json {
            self = .absolute(path)
        } else if case .string(let relative)? = json["$item"] {
            self = .item(relative)
        } else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Invalid repeat statePath.")
            )
        }
    }

    public func encode(to encoder: any Encoder) throws {
        switch self {
        case .absolute(let path): try JSONValue.string(path).encode(to: encoder)
        case .item(let relative):
            try JSONValue.object(["$item": .string(relative)]).encode(to: encoder)
        }
    }
}
