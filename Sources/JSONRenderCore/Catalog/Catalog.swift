/// The components, actions, functions and directives a spec may use.
///
/// jr-1a seed: the parts that action dispatch and expression resolution need (`actions`,
/// `actionOrder`, `functions`, `directives` and their registration methods). jr-1b adds
/// components, validators, renderers, the built-in action descriptions, `prompt()`,
/// `jsonSchema(strict:)` and `validate(_:)`.
public struct Catalog: Sendable {
    /// Actions by name.
    public var actions: [String: ActionDefinition]
    /// Action names in registration order (prompt output depends on it).
    public var actionOrder: [String]
    /// Functions for `$computed`.
    public var functions: [String: ComputedFunction]
    /// Custom directives.
    public var directives: DirectiveRegistry

    /// `actions` given here are ordered by name, because a dictionary has no stable order.
    public init(actions: [String: ActionDefinition] = [:]) {
        self.actions = actions
        self.actionOrder = actions.keys.sorted()
        self.functions = [:]
        self.directives = DirectiveRegistry()
    }

    /// Registers or replaces an action. A new name goes to the end of `actionOrder`.
    public mutating func action(
        _ name: String, params: PropSchema = .object([]), description: String = "",
        handler: ActionHandler? = nil
    ) {
        if actions[name] == nil { actionOrder.append(name) }
        actions[name] = ActionDefinition(params: params, description: description, handler: handler)
    }

    /// Registers or replaces a `$computed` function.
    public mutating func function(_ name: String, _ body: @escaping ComputedFunction) {
        functions[name] = body
    }

    /// Registers or replaces a directive.
    public mutating func directive(_ definition: DirectiveDefinition) {
        directives.register(definition)
    }
}
