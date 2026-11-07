/// An event-to-action binding (upstream `ActionBinding`, `actions.ts`).
public struct ActionBinding: Sendable, Hashable {
    /// The action name: a built-in or a catalog action.
    public var action: String
    /// Raw params. Values may hold expressions; they resolve at dispatch time.
    public var params: [String: JSONValue]?
    /// A confirmation dialog shown before the action runs.
    public var confirm: ActionConfirm?
    public var onSuccess: ActionOnSuccess?
    public var onError: ActionOnError?
    /// Whether the host's default behaviour for the event should be suppressed.
    public var preventDefault: Bool?

    public init(
        action: String, params: [String: JSONValue]? = nil, confirm: ActionConfirm? = nil,
        onSuccess: ActionOnSuccess? = nil, onError: ActionOnError? = nil,
        preventDefault: Bool? = nil
    ) {
        self.action = action
        self.params = params
        self.confirm = confirm
        self.onSuccess = onSuccess
        self.onError = onError
        self.preventDefault = preventDefault
    }
}

/// A confirmation dialog (upstream `ActionConfirm`).
public struct ActionConfirm: Sendable, Hashable {
    public enum Variant: String, Sendable, Hashable, Codable {
        case `default`
        case danger
    }

    public var title: String
    public var message: String
    public var confirmLabel: String?
    public var cancelLabel: String?
    public var variant: Variant?

    public init(
        title: String, message: String, confirmLabel: String? = nil, cancelLabel: String? = nil,
        variant: Variant? = nil
    ) {
        self.title = title
        self.message = message
        self.confirmLabel = confirmLabel
        self.cancelLabel = cancelLabel
        self.variant = variant
    }
}

/// What happens after a handler succeeds.
public enum ActionOnSuccess: Sendable, Hashable {
    /// `{ "navigate": "/path" }`: asks the host to navigate.
    case navigate(String)
    /// `{ "set": { "/path": value } }`: writes literal values to state.
    case set([String: JSONValue])
    /// `{ "action": "name", "params": {…} }`: dispatches another action.
    case action(String, params: [String: JSONValue]?)
}

/// What happens after a handler throws.
public enum ActionOnError: Sendable, Hashable {
    /// `{ "set": { "/path": value } }`. The literal string `"$error.message"` becomes the
    /// error message.
    case set([String: JSONValue])
    /// `{ "action": "name", "params": {…} }`.
    case action(String, params: [String: JSONValue]?)
}

// MARK: - JSON conversion

extension ActionBinding {
    /// Builds a binding from JSON. Throws `.shape` for a missing `action` or a wrong type.
    public init(json: JSONValue) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("An action binding is not an object.")
        }
        guard case .string(let action)? = members["action"] else {
            throw .shape("An action binding has no string \"action\".")
        }
        self.action = action
        params = try ActionBinding.params(members["params"])
        switch members["confirm"] {
        case nil, .null?: confirm = nil
        case let raw?: confirm = try ActionConfirm(json: raw)
        }
        switch members["onSuccess"] {
        case nil, .null?: onSuccess = nil
        case let raw?: onSuccess = try ActionOnSuccess(json: raw)
        }
        switch members["onError"] {
        case nil, .null?: onError = nil
        case let raw?: onError = try ActionOnError(json: raw)
        }
        switch members["preventDefault"] {
        case nil, .null?: preventDefault = nil
        case .bool(let flag)?: preventDefault = flag
        default: throw .shape("An action binding has a non-Boolean \"preventDefault\".")
        }
    }

    public var jsonValue: JSONValue {
        var members: [String: JSONValue] = ["action": .string(action)]
        if let params { members["params"] = .object(params) }
        if let confirm { members["confirm"] = confirm.jsonValue }
        if let onSuccess { members["onSuccess"] = onSuccess.jsonValue }
        if let onError { members["onError"] = onError.jsonValue }
        if let preventDefault { members["preventDefault"] = .bool(preventDefault) }
        return .object(members)
    }

    static func params(_ value: JSONValue?) throws(SpecDecodeError) -> [String: JSONValue]? {
        switch value {
        case nil, .null?: return nil
        case .object(let members)?: return members
        default: throw .shape("Action \"params\" is not an object.")
        }
    }
}

extension ActionConfirm {
    init(json: JSONValue) throws(SpecDecodeError) {
        guard case .object(let members) = json, case .string(let title)? = members["title"],
            case .string(let message)? = members["message"]
        else { throw .shape("An action \"confirm\" needs string \"title\" and \"message\".") }
        self.title = title
        self.message = message
        confirmLabel = members["confirmLabel"]?.stringValue
        cancelLabel = members["cancelLabel"]?.stringValue
        variant = members["variant"]?.stringValue.flatMap(Variant.init(rawValue:))
    }

    var jsonValue: JSONValue {
        var members: [String: JSONValue] = ["title": .string(title), "message": .string(message)]
        if let confirmLabel { members["confirmLabel"] = .string(confirmLabel) }
        if let cancelLabel { members["cancelLabel"] = .string(cancelLabel) }
        if let variant { members["variant"] = .string(variant.rawValue) }
        return .object(members)
    }
}

extension ActionOnSuccess {
    init(json: JSONValue) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("\"onSuccess\" is not an object.")
        }
        // Upstream checks `navigate`, then `set`, then `action`.
        if case .string(let path)? = members["navigate"] {
            self = .navigate(path)
        } else if case .object(let values)? = members["set"] {
            self = .set(values)
        } else if case .string(let name)? = members["action"] {
            self = .action(name, params: try ActionBinding.params(members["params"]))
        } else {
            throw .shape("\"onSuccess\" needs \"navigate\", \"set\" or \"action\".")
        }
    }

    var jsonValue: JSONValue {
        switch self {
        case .navigate(let path): .object(["navigate": .string(path)])
        case .set(let values): .object(["set": .object(values)])
        case .action(let name, let params):
            params.map { .object(["action": .string(name), "params": .object($0)]) }
                ?? .object(["action": .string(name)])
        }
    }
}

extension ActionOnError {
    init(json: JSONValue) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("\"onError\" is not an object.")
        }
        if case .object(let values)? = members["set"] {
            self = .set(values)
        } else if case .string(let name)? = members["action"] {
            self = .action(name, params: try ActionBinding.params(members["params"]))
        } else {
            throw .shape("\"onError\" needs \"set\" or \"action\".")
        }
    }

    var jsonValue: JSONValue {
        switch self {
        case .set(let values): .object(["set": .object(values)])
        case .action(let name, let params):
            params.map { .object(["action": .string(name), "params": .object($0)]) }
                ?? .object(["action": .string(name)])
        }
    }
}

// MARK: - Codable

/// Codable through `JSONValue`, so the JSON shapes stay in one place.
private func decodeThroughJSON<T>(
    _ decoder: any Decoder, _ build: (JSONValue) throws(SpecDecodeError) -> T
) throws -> T {
    let json = try JSONValue(from: decoder)
    do {
        return try build(json)
    } catch {
        throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: error.message))
    }
}

extension ActionBinding: Codable {
    public init(from decoder: any Decoder) throws {
        self = try decodeThroughJSON(decoder) { json throws(SpecDecodeError) in
            try ActionBinding(json: json)
        }
    }

    public func encode(to encoder: any Encoder) throws { try jsonValue.encode(to: encoder) }
}

extension ActionConfirm: Codable {
    public init(from decoder: any Decoder) throws {
        self = try decodeThroughJSON(decoder) { json throws(SpecDecodeError) in
            try ActionConfirm(json: json)
        }
    }

    public func encode(to encoder: any Encoder) throws { try jsonValue.encode(to: encoder) }
}

extension ActionOnSuccess: Codable {
    public init(from decoder: any Decoder) throws {
        self = try decodeThroughJSON(decoder) { json throws(SpecDecodeError) in
            try ActionOnSuccess(json: json)
        }
    }

    public func encode(to encoder: any Encoder) throws { try jsonValue.encode(to: encoder) }
}

extension ActionOnError: Codable {
    public init(from decoder: any Decoder) throws {
        self = try decodeThroughJSON(decoder) { json throws(SpecDecodeError) in
            try ActionOnError(json: json)
        }
    }

    public func encode(to encoder: any Encoder) throws { try jsonValue.encode(to: encoder) }
}
