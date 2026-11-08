public import JSONRenderCore

/// One app-owned element recipe (upstream `Experimental_CompositionCandidate`). The
/// evaluator sees only `id` and `description`; it can never change props or bindings.
public struct CompositionCandidate: Sendable, Hashable, Codable {
    public var id: String
    /// The text the evaluator reads. Write what the element shows, not how.
    public var description: String
    /// `type`, `props`, `on` and `visible` are used. `children` and `slots` are ignored (the
    /// composer adds them). `repeat` and `watch` are refused.
    public var element: UIElement
    /// Whether this candidate can be the root.
    public var root: Bool
    /// How many times the candidate can appear. Values above one make it a repeatable
    /// layout element.
    public var maxUses: Int
    /// Candidates that share a resource are mutually exclusive.
    public var resource: String?

    public init(
        id: String, description: String, element: UIElement, root: Bool = true,
        maxUses: Int = 1, resource: String? = nil
    ) {
        self.id = id
        self.description = description
        self.element = element
        self.root = root
        self.maxUses = maxUses
        self.resource = resource
    }

    enum CodingKeys: String, CodingKey {
        case id, description, element, root, maxUses, resource
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        description = try container.decode(String.self, forKey: .description)
        element = try container.decode(UIElement.self, forKey: .element)
        root = try container.decodeIfPresent(Bool.self, forKey: .root) ?? true
        maxUses = try container.decodeIfPresent(Int.self, forKey: .maxUses) ?? 1
        resource = try container.decodeIfPresent(String.self, forKey: .resource)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(description, forKey: .description)
        try container.encode(element, forKey: .element)
        try container.encode(root, forKey: .root)
        try container.encode(maxUses, forKey: .maxUses)
        try container.encodeIfPresent(resource, forKey: .resource)
    }
}
