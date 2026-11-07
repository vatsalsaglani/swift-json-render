/// A spec rule a catalog adds to `validate`: it receives the spec and its initial state
/// and returns extra issues (use `SpecIssue.Code.customRule` and set `rule`).
public typealias SpecRule = @Sendable (_ spec: Spec, _ state: JSONValue?) -> [SpecIssue]

/// The components, actions, functions, directives, validators and rules a spec may use.
///
/// The component registry is append-only and ordered: the prompt and the JSON Schema list
/// components in registration order. `JSONRenderSwiftUI` adds renderers.
public struct Catalog: Sendable {
    /// Component definitions in registration order.
    public private(set) var components: [ComponentDefinition]
    /// Actions by name.
    public var actions: [String: ActionDefinition]
    /// Action names in registration order (prompt output depends on it).
    public var actionOrder: [String]
    /// Functions for `$computed`.
    public var functions: [String: ComputedFunction]
    /// `$computed` names in registration order (the prompt lists them).
    public private(set) var functionOrder: [String]
    /// `$computed` descriptions for the prompt (empty string: name only).
    public private(set) var functionDescriptions: [String: String]
    /// Custom directives.
    public var directives: DirectiveRegistry
    /// Custom validation functions (built-in names win at run time).
    public var validators: [String: ValidationFunctionDefinition]
    /// Platform renderers by component name. Empty on Linux.
    public var renderers: [String: any ComponentRenderer]
    /// The upstream built-in actions (verbatim React schema text).
    public var builtInActions: [BuiltInActionDescription]
    /// The Swift extension actions (`toggleState`, `incrementState`).
    public var extensionActions: [BuiltInActionDescription]
    /// The React schema default rules (verbatim).
    public var defaultRules: [String]
    /// Extra spec rules by name, run by `validate` after the built-in checks.
    public private(set) var rules: [String: SpecRule]
    /// Rule names in registration order (the run order).
    public private(set) var ruleOrder: [String]

    private var componentIndex: [String: Int]

    /// `components` keep their order; a later duplicate name is ignored (use `register` to
    /// get an error). `actions` given here are ordered by name, because a dictionary has no
    /// order.
    public init(components: [ComponentDefinition] = [], actions: [String: ActionDefinition] = [:]) {
        self.components = []
        self.componentIndex = [:]
        self.actions = actions
        self.actionOrder = actions.keys.sorted()
        self.functions = [:]
        self.functionOrder = []
        self.functionDescriptions = [:]
        self.directives = DirectiveRegistry()
        self.validators = [:]
        self.renderers = [:]
        self.builtInActions = ReactSchemaText.builtInActions
        self.extensionActions = ReactSchemaText.extensionActions
        self.defaultRules = ReactSchemaText.defaultRules
        self.rules = [:]
        self.ruleOrder = []
        for definition in components where componentIndex[definition.name] == nil {
            componentIndex[definition.name] = self.components.count
            self.components.append(definition)
        }
    }

    // MARK: - Components

    /// The definition named `name`.
    public func component(named name: String) -> ComponentDefinition? {
        componentIndex[name].map { components[$0] }
    }

    /// Component names in registration order.
    public var componentNames: [String] { components.map(\.name) }

    /// Appends a definition. A name that already exists throws.
    public mutating func register(_ definition: ComponentDefinition) throws(CatalogError) {
        guard componentIndex[definition.name] == nil else {
            throw .duplicateComponent(definition.name)
        }
        componentIndex[definition.name] = components.count
        components.append(definition)
    }

    /// Appends `C.definition` (data only; the SwiftUI overload also adds the renderer).
    ///
    /// Generic on purpose: a non-generic `any JRComponentType.Type` overload would win
    /// overload resolution over `JSONRenderSwiftUI`'s `register<C: View & JRComponentType>`,
    /// and `catalog.register(MyView.self)` would silently drop the renderer. With both generic,
    /// the more constrained SwiftUI overload is chosen whenever `C` is a `View`.
    public mutating func register<C: JRComponentType>(_ type: C.Type) throws(CatalogError) {
        try register(C.definition)
    }

    /// Replaces the definition of an existing component, keeping its position.
    public mutating func replaceDefinition(_ definition: ComponentDefinition)
        throws(CatalogError)
    {
        guard let index = componentIndex[definition.name] else {
            throw .unknownComponent(definition.name)
        }
        components[index] = definition
    }

    // MARK: - Actions, functions, directives, validators, rules

    /// Registers or replaces an action. A new name goes to the end of `actionOrder`.
    public mutating func action(
        _ name: String, params: PropSchema = .object([]), description: String = "",
        handler: ActionHandler? = nil
    ) {
        if actions[name] == nil { actionOrder.append(name) }
        actions[name] = ActionDefinition(params: params, description: description, handler: handler)
    }

    /// Registers or replaces a `$computed` function. The prompt lists `name — description`
    /// (or only the name when `description` is empty).
    public mutating func function(
        _ name: String, description: String = "", _ body: @escaping ComputedFunction
    ) {
        if functions[name] == nil { functionOrder.append(name) }
        functions[name] = body
        functionDescriptions[name] = description
    }

    /// Registers or replaces a directive.
    public mutating func directive(_ definition: DirectiveDefinition) {
        directives.register(definition)
    }

    /// Registers or replaces a custom validation function.
    public mutating func validator(
        _ name: String, description: String? = nil, _ function: @escaping ValidationFunction
    ) {
        validators[name] = ValidationFunctionDefinition(
            description: description, validate: function)
    }

    /// Registers or replaces a spec rule. `validate` runs rules in registration order.
    public mutating func rule(_ name: String, _ body: @escaping SpecRule) {
        if rules[name] == nil { ruleOrder.append(name) }
        rules[name] = body
    }

    /// The custom validation functions, for `Validator` and `FormValidator`.
    public var validationFunctions: [String: ValidationFunction] {
        validators.mapValues(\.validate)
    }

    // MARK: - Merging

    /// The union of two catalogs. Any name defined in both (component, action, function,
    /// directive, validator, rule, renderer) throws. Built-in text and default rules come
    /// from `self`. `other`'s entries follow `self`'s in every order.
    public func merging(_ other: Catalog) throws(CatalogError) -> Catalog {
        var merged = self
        for definition in other.components { try merged.register(definition) }
        for name in other.actionOrder {
            guard merged.actions[name] == nil else { throw .duplicateAction(name) }
            if let action = other.actions[name] {
                merged.actions[name] = action
                merged.actionOrder.append(name)
            }
        }
        let functionNames = other.orderedFunctionNames
        for name in functionNames where merged.functions[name] != nil {
            throw .duplicateFunction(name)
        }
        for name in functionNames {
            if let function = other.functions[name] {
                merged.function(
                    name, description: other.functionDescriptions[name] ?? "", function)
            }
        }
        for definition in other.directives.definitions {
            guard merged.directives[definition.name] == nil else {
                throw .duplicateDirective(definition.name)
            }
            merged.directive(definition)
        }
        for name in other.validators.keys.sorted() {
            guard merged.validators[name] == nil else { throw .duplicateValidator(name) }
            merged.validators[name] = other.validators[name]
        }
        for name in other.ruleOrder {
            guard merged.rules[name] == nil else { throw .duplicateRule(name) }
            if let rule = other.rules[name] { merged.rule(name, rule) }
        }
        for name in other.renderers.keys.sorted() {
            guard merged.renderers[name] == nil else { throw .duplicateRenderer(name) }
            merged.renderers[name] = other.renderers[name]
        }
        return merged
    }
}
