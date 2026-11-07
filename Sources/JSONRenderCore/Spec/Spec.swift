public import Foundation

/// A flat json-render spec: `{ root, elements, state? }` (upstream `Spec`).
public struct Spec: Sendable, Hashable {
    /// The root element id. `""` when absent.
    public var root: String
    /// Elements by id.
    public var elements: [String: UIElement]
    /// The initial state: an object, or `nil`.
    public var state: JSONValue?

    public init(root: String, elements: [String: UIElement], state: JSONValue? = nil) {
        self.root = root
        self.elements = elements
        self.state = state
    }
}

/// A decoded spec with the decoder's warnings.
public struct DecodedSpec: Sendable {
    public let spec: Spec
    public let warnings: [SpecDecodeWarning]

    public init(spec: Spec, warnings: [SpecDecodeWarning]) {
        self.spec = spec
        self.warnings = warnings
    }
}

/// A non-fatal decoding note. Warnings carry ids and key names, never values.
public enum SpecDecodeWarning: Sendable, Hashable {
    /// An element key that `UIElement` does not model. The key is dropped.
    case unknownElementKey(element: String, key: String)
    /// `on` or `watch` held one binding object, stored as a one-element array. This is a
    /// valid upstream form; the warning only records the normalisation.
    case singleBindingNormalised(element: String, event: String)
    /// A `visible` condition with several comparison operators; upstream precedence kept one.
    case extraVisibilityOperators(element: String, kept: String, ignored: [String])
    /// `state` was present but not an object; it was dropped.
    case nonObjectState
}

/// Why a spec could not be decoded.
public enum SpecDecodeError: Error, Sendable, Hashable {
    /// The document is larger than `SpecLimits.maxBytes`.
    case tooLarge(bytes: Int, limit: Int)
    /// The bytes are not JSON. The message is the parser's, without document content.
    case invalidJSON(String)
    /// The JSON does not have the spec shape.
    case shape(String)

    /// A short description without document values.
    public var message: String {
        switch self {
        case .tooLarge(let bytes, let limit): "The spec is \(bytes) bytes; the limit is \(limit)."
        case .invalidJSON(let reason): "The spec is not valid JSON: \(reason)"
        case .shape(let reason): reason
        }
    }
}

// MARK: - Decoding

extension Spec {
    /// Decodes a spec document.
    ///
    /// Checks the size cap first, then parses JSON, then builds the spec. Unknown element
    /// keys and other normalisations are returned as warnings. Element-count, depth and
    /// repeat caps are spec-validator checks, not decoder checks.
    public static func decode(_ data: Data, limits: SpecLimits = .default) throws(SpecDecodeError)
        -> DecodedSpec
    {
        guard data.count <= limits.maxBytes else {
            throw .tooLarge(bytes: data.count, limit: limits.maxBytes)
        }
        let json: JSONValue
        do {
            json = try JSONDecoder().decode(JSONValue.self, from: data)
        } catch let error as DecodingError {
            throw .invalidJSON(Spec.describe(error))
        } catch {
            throw .invalidJSON("The data could not be read.")
        }
        var warnings: [SpecDecodeWarning] = []
        let spec = try Spec(json: json, warnings: &warnings)
        return DecodedSpec(spec: spec, warnings: warnings)
    }

    /// Builds a spec from parsed JSON, without warnings.
    public init(json: JSONValue) throws(SpecDecodeError) {
        var warnings: [SpecDecodeWarning] = []
        try self.init(json: json, warnings: &warnings)
    }

    init(json: JSONValue, warnings: inout [SpecDecodeWarning]) throws(SpecDecodeError) {
        guard case .object(let members) = json else {
            throw .shape("The spec is not an object.")
        }
        switch members["root"] {
        case nil, .null?: root = ""
        case .string(let id)?: root = id
        default: throw .shape("The spec \"root\" is not a string.")
        }
        var elements: [String: UIElement] = [:]
        switch members["elements"] {
        case nil, .null?:
            break
        case .object(let rawElements)?:
            for id in rawElements.keys.sorted() {
                guard let raw = rawElements[id] else { continue }
                elements[id] = try UIElement(json: raw, id: id, warnings: &warnings)
            }
        default:
            throw .shape("The spec \"elements\" is not an object.")
        }
        self.elements = elements
        switch members["state"] {
        case nil, .null?: state = nil
        case .object?: state = members["state"]
        default:
            state = nil
            warnings.append(.nonObjectState)
        }
    }

    /// The JSON form. `state` is omitted when `nil`.
    public var jsonValue: JSONValue {
        var members: [String: JSONValue] = [
            "root": .string(root),
            "elements": .object(elements.mapValues(\.jsonValue)),
        ]
        if let state { members["state"] = state }
        return .object(members)
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .dataCorrupted(let context): context.debugDescription
        case .keyNotFound(_, let context): context.debugDescription
        case .typeMismatch(_, let context): context.debugDescription
        case .valueNotFound(_, let context): context.debugDescription
        @unknown default: "Unknown decoding error."
        }
    }
}

extension Spec: Codable {
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
