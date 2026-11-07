/// A custom directive: a user-defined `$`-prefixed dynamic value (upstream `directives.ts`).
///
/// Directives are registered Swift closures. Specs only name them; no spec ever carries code.
public struct DirectiveDefinition: Sendable {
    /// The `$`-prefixed key that triggers the directive, for example `"$format"`.
    public let name: String
    /// A short description for the generated prompt.
    public let description: String?
    /// The directive object's shape, for the generated prompt.
    public let schema: PropSchema
    /// Receives the whole raw directive object. It may call `resolver.resolveValue(_:)` on
    /// sub-values to compose with other expressions.
    public let resolve: @Sendable (_ value: JSONValue, _ resolver: inout PropResolver) -> JSONValue?

    /// Upstream `defineDirective`: the name must start with `$` and must not be a built-in
    /// expression key.
    public init(
        name: String, description: String? = nil, schema: PropSchema,
        resolve:
            @escaping @Sendable (_ value: JSONValue, _ resolver: inout PropResolver) ->
            JSONValue?
    ) throws(DirectiveError) {
        guard name.hasPrefix("$") else { throw .missingDollarPrefix(name) }
        guard !PropExpression.builtInKeys.contains(name) else {
            throw .conflictsWithBuiltIn(name)
        }
        self.name = name
        self.description = description
        self.schema = schema
        self.resolve = resolve
    }
}

/// Why a directive definition was refused.
public enum DirectiveError: Error, Sendable, Equatable {
    /// Upstream: `Directive name must start with "$"`.
    case missingDollarPrefix(String)
    /// Upstream: `Directive name "…" conflicts with a built-in prop expression key`.
    case conflictsWithBuiltIn(String)
}

/// Directives by name, in registration order (upstream `createDirectiveRegistry`, a `Map`).
/// A later definition with the same name replaces the earlier one and keeps its position.
public struct DirectiveRegistry: Sendable {
    public private(set) var definitions: [DirectiveDefinition]

    public init(_ definitions: [DirectiveDefinition] = []) {
        self.definitions = []
        for definition in definitions { register(definition) }
    }

    /// Adds or replaces a definition.
    public mutating func register(_ definition: DirectiveDefinition) {
        if let index = definitions.firstIndex(where: { $0.name == definition.name }) {
            definitions[index] = definition
        } else {
            definitions.append(definition)
        }
    }

    /// The registered names.
    public var names: Set<String> { Set(definitions.map(\.name)) }

    /// The names in registration order.
    public var orderedNames: [String] { definitions.map(\.name) }

    public var isEmpty: Bool { definitions.isEmpty }

    public subscript(name: String) -> DirectiveDefinition? {
        definitions.first { $0.name == name }
    }
}
