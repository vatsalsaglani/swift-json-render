/// What the catalog says about one component: the data the prompt, the JSON Schema and the
/// validator read. The view lives in a renderer (`JSONRenderSwiftUI`'s `ViewFactory`).
public struct ComponentDefinition: Sendable, Hashable {
    /// The element `type`.
    public var name: String
    public var description: String
    /// An object schema. Its field order is the prompt order.
    public var props: PropSchema
    /// Slot names. `"default"` means the component accepts `children`.
    public var slots: [String]
    /// Event names for the element `on` field.
    public var events: [String]
    /// Example props for the prompt. When `nil` or empty, the example is generated from
    /// `props` (required fields only). Keys print in `props` field order, then the rest in
    /// code-point order.
    public var example: [String: JSONValue]?
    /// Prop names that hold secrets (for example a password input `value`). Hosts must not
    /// persist or log these props or the state paths they bind to. Set by
    /// `@JRProp(secret: true)`.
    public var secretProps: [String]

    public init(
        name: String, description: String = "", props: PropSchema = .object([]),
        slots: [String] = [], events: [String] = [], example: [String: JSONValue]? = nil,
        secretProps: [String] = []
    ) {
        self.name = name
        self.description = description
        self.props = props
        self.slots = slots
        self.events = events
        self.example = example
        self.secretProps = secretProps
    }

    /// `true` when the component has the `"default"` slot.
    public var acceptsChildren: Bool { slots.contains("default") }
}

/// A component type the `@JRComponent` macro generates: a definition and an initialiser
/// from a render context. `JSONRenderSwiftUI` registers `View & JRComponentType` types.
///
/// `definition` must be `nonisolated` (the macro generates `nonisolated static let`), so a
/// main-actor view can satisfy it. Not `Sendable`: views hold a `JRRenderContext`, which is
/// main-actor data.
public protocol JRComponentType {
    static var definition: ComponentDefinition { get }
    @MainActor init(context: JRRenderContext)
}

/// The element ids of one child region, in order. `JSONRenderSwiftUI` makes it a `View`.
public struct JRChildren: Sendable, Hashable {
    public let ids: [String]

    public init(ids: [String]) {
        self.ids = ids
    }

    public static let empty = JRChildren(ids: [])

    public var isEmpty: Bool { ids.isEmpty }
}

/// Everything a component receives for one render.
///
/// Not `Sendable` on purpose: `emit` is a main-actor closure and the context is built and
/// read on the main actor.
public struct JRRenderContext {
    /// The element id.
    public let id: String
    /// The resolved props. `nil` (`.none`) is upstream undefined; `.some(.null)` is JSON
    /// `null`. Read with `context.props[name] ?? nil`.
    public let props: [String: JSONValue?]
    /// Prop name to the absolute state path it binds (`$bindState` / `$bindItem`).
    public let bindings: [String: JSONPointer]
    /// The `children` region.
    public let children: JRChildren
    /// The named slots.
    public let slots: [String: JRChildren]
    /// The repeat row this element renders in, if any.
    public let scope: RepeatScope?
    /// Fires the bindings of `event` from the element `on` field.
    public let emit: @MainActor (_ event: String, _ payload: [String: JSONValue]) -> Void
    /// `true` while the spec is still streaming.
    public let isStreaming: Bool

    public init(
        id: String, props: [String: JSONValue?] = [:], bindings: [String: JSONPointer] = [:],
        children: JRChildren = .empty, slots: [String: JRChildren] = [:],
        scope: RepeatScope? = nil,
        emit: @escaping @MainActor (_ event: String, _ payload: [String: JSONValue]) -> Void = {
            _, _ in
        },
        isStreaming: Bool = false
    ) {
        self.id = id
        self.props = props
        self.bindings = bindings
        self.children = children
        self.slots = slots
        self.scope = scope
        self.emit = emit
        self.isStreaming = isStreaming
    }

    /// The resolved prop `name`; `nil` when absent or undefined.
    public func prop(_ name: String) -> JSONValue? { props[name] ?? nil }
}

/// A marker for platform renderers stored in `Catalog.renderers`. `JSONRenderSwiftUI`'s
/// `ViewFactory` conforms. It keeps Core free of UI frameworks.
public protocol ComponentRenderer: Sendable {}

/// A catalog registration problem.
public enum CatalogError: Error, Sendable, Hashable {
    case duplicateComponent(String)
    case duplicateAction(String)
    case duplicateFunction(String)
    case duplicateDirective(String)
    case duplicateValidator(String)
    case duplicateRule(String)
    case duplicateRenderer(String)
    /// `override` named a component the catalog does not define.
    case unknownComponent(String)
}
