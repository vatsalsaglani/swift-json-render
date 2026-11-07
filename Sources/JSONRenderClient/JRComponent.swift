// Owner: jr-1b (wave 1). The `@JRComponent` / `@JRProp` declarations; JSONRenderMacros implements them.
@_exported public import JSONRenderCore

/// Generates a component's catalog definition and its initialiser from a render context.
///
/// On a struct with `@JRProp` stored properties it adds:
/// - `nonisolated public static let definition: ComponentDefinition` (props in declaration
///   order; `T?` is nullable, a default value makes the prop optional);
/// - `public let jrContext: JRRenderContext`;
/// - `public init(context: JRRenderContext)`, which reads each prop with
///   `context.props[name] ?? nil` and coerces it; a missing prop takes its default value,
///   `nil` for an optional, or the type's zero (`""`, `0`, `false`, `[]`, `.null`);
/// - a `JRComponentType` conformance.
///
/// Supported prop types: `String`, `Double`, `Float`, `CGFloat`, `Int` (rounded), `Bool`,
/// `JSONValue`, `[T]` and `T?` of those (so `[JSONValue]` for object lists such as tabs or
/// rows).
@attached(member, names: named(definition), named(init(context:)), named(jrContext))
@attached(extension, conformances: JRComponentType)
public macro JRComponent(
    _ name: String, description: String = "", slots: [String] = [], events: [String] = []
) = #externalMacro(module: "JSONRenderMacros", type: "JRComponentMacro")

/// Marks a stored property as a component prop. `@JRComponent` reads it.
/// - `description`: the prop description in the definition.
/// - `oneOf`: allowed values (a `String` prop only); the schema becomes an enum.
/// - `bindable`: documents that the prop takes `{ "$bindState": … }`; no schema change.
/// - `secret`: lists the prop in `ComponentDefinition.secretProps`.
@attached(peer)
public macro JRProp(
    description: String = "", oneOf: [String] = [], bindable: Bool = false, secret: Bool = false
) = #externalMacro(module: "JSONRenderMacros", type: "JRPropMacro")
