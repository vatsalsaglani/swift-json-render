/// An element with its own id and parent id, for `Spec.flatToTree` (upstream
/// `FlatElement`). In JSON the element fields sit beside `key` and `parentKey`.
public struct FlatElement: Sendable, Hashable {
    public var key: String
    /// The parent id. `nil` or `""` marks a root candidate.
    public var parentKey: String?
    public var element: UIElement

    public init(key: String, parentKey: String? = nil, element: UIElement) {
        self.key = key
        self.parentKey = parentKey
        self.element = element
    }
}

extension FlatElement: Codable {
    public init(from decoder: any Decoder) throws {
        let json = try JSONValue(from: decoder)
        guard case .object(var members) = json, case .string(let key)? = members["key"] else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "No string \"key\"."))
        }
        let parentKey = members["parentKey"]?.stringValue
        members["key"] = nil
        members["parentKey"] = nil
        do {
            element = try UIElement(json: .object(members), id: key)
        } catch {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: error.message))
        }
        self.key = key
        self.parentKey = parentKey
    }

    public func encode(to encoder: any Encoder) throws {
        guard case .object(var members) = element.jsonValue else { return }
        members["key"] = .string(key)
        if let parentKey { members["parentKey"] = .string(parentKey) }
        try JSONValue.object(members).encode(to: encoder)
    }
}
