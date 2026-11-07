// Stream types: declarations only. jr-2 implements decoding and patch application.

/// The RFC 6902 operations (upstream `PatchOp`).
public enum PatchOperation: String, Sendable, Hashable, Codable, CaseIterable {
    case add, remove, replace, move, copy, test
}

/// One SpecStream line (upstream `JsonPatch`). `path` and `from` stay strings; jr-2 parses
/// them tolerantly. `"value": null` decodes as `.null`; an absent `value` is `nil`.
public struct SpecPatch: Sendable, Hashable, Codable {
    public var op: PatchOperation
    public var path: String
    /// Required for `add`, `replace` and `test`.
    public var value: JSONValue?
    /// Required for `move` and `copy`.
    public var from: String?

    public init(op: PatchOperation, path: String, value: JSONValue? = nil, from: String? = nil) {
        self.op = op
        self.path = path
        self.value = value
        self.from = from
    }

    private enum CodingKeys: String, CodingKey {
        case op, path, value, from
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        op = try container.decode(PatchOperation.self, forKey: .op)
        path = try container.decode(String.self, forKey: .path)
        value =
            container.contains(.value) ? try container.decode(JSONValue.self, forKey: .value) : nil
        from = try container.decodeIfPresent(String.self, forKey: .from)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(op, forKey: .op)
        try container.encode(path, forKey: .path)
        if let value { try container.encode(value, forKey: .value) }
        try container.encodeIfPresent(from, forKey: .from)
    }
}

/// A limit that a stream can exceed.
public enum SpecLimitKind: String, Sendable, Hashable {
    case bytes, elements, depth, repeatRows, buffer
}

/// A stream problem. Carries indexes, operations and paths, never values.
public enum StreamError: Error, Sendable, Hashable {
    case badLine(index: Int, reason: String)
    case patchFailed(index: Int, op: PatchOperation, path: String, reason: String)
    case unrecoverable(String)
    case budget(SpecLimitKind)
}

/// One decoded stream event.
public enum SpecStreamEvent: Sendable, Hashable {
    case patch(SpecPatch)
    case text(String)
    case error(StreamError)
}

/// One committed state of a streaming spec: what a renderer draws. The stream layer builds
/// `plan` once per commit (never in a view body).
public struct SpecSnapshot: Sendable, Hashable {
    /// Increases by one per commit.
    public let version: UInt64
    public let spec: Spec
    public let plan: RenderPlan
    /// Ids referenced but not defined yet (normally `plan.dangling`).
    public let dangling: Set<String>
    /// `true` for the last snapshot of a stream.
    public let isFinal: Bool
    /// The stream problems so far (ids, operations and paths; never values).
    public let journal: [StreamError]

    public init(
        version: UInt64, spec: Spec, plan: RenderPlan, dangling: Set<String>? = nil,
        isFinal: Bool = false, journal: [StreamError] = []
    ) {
        self.version = version
        self.spec = spec
        self.plan = plan
        self.dangling = dangling ?? plan.dangling
        self.isFinal = isFinal
        self.journal = journal
    }

    /// A snapshot of `spec` with a freshly built plan.
    public init(
        version: UInt64, spec: Spec, limits: SpecLimits = .default, isFinal: Bool = false,
        journal: [StreamError] = []
    ) {
        self.init(
            version: version, spec: spec, plan: RenderPlan(spec: spec, limits: limits),
            isFinal: isFinal, journal: journal)
    }
}
