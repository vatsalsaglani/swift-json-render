/// Options for `Catalog.prompt(_:)` (upstream `PromptOptions`).
public struct PromptOptions: Sendable {
    public enum Mode: Sendable, Hashable {
        /// Output only JSONL patches.
        case standalone
        /// Answer in prose first, then JSONL patches in a ```spec fence.
        case inline
    }

    public var system: String
    public var mode: Mode
    /// Appended after the default rules.
    public var customRules: [String]
    /// Directives for the CUSTOM DYNAMIC VALUES section. `nil` uses the catalog's
    /// directives (upstream lists only the directives passed in the options).
    public var directives: [DirectiveDefinition]?
    /// Edit modes to document. `nil` or empty omits the section (upstream default).
    public var editModes: [EditMode]?
    /// Lists the Swift extension actions (`toggleState`, `incrementState`) after the
    /// built-in actions. `false` gives the upstream text.
    public var includeExtensions: Bool

    public init(
        system: String = "You are a UI generator that outputs JSON.", mode: Mode = .standalone,
        customRules: [String] = [], directives: [DirectiveDefinition]? = nil,
        editModes: [EditMode]? = nil, includeExtensions: Bool = true
    ) {
        self.system = system
        self.mode = mode
        self.customRules = customRules
        self.directives = directives
        self.editModes = editModes
        self.includeExtensions = includeExtensions
    }
}

extension Catalog {
    /// The system prompt (upstream `generatePrompt` with the React schema).
    ///
    /// With `includeExtensions: false` and a catalog built like the upstream one, the text
    /// equals upstream byte for byte. Additions over upstream: the extension actions,
    /// `$computed` descriptions (`name — description`), and catalog validators listed after
    /// the built-in validation types.
    public func prompt(_ options: PromptOptions = PromptOptions()) -> String {
        var lines: [String] = [options.system, ""]
        let inline = options.mode == .inline
        appendOutputFormat(&lines, inline: inline)

        let names = componentNames
        let first = names.first ?? "Component"
        let second = names.count > 1 ? names[1] : first
        let firstProps = examplePropsFor(component(named: first))
        let secondProps = examplePropsFor(component(named: second))
        var dynamicProps = secondProps
        if let field = component(named: second)?.props.firstRequiredStringField() {
            let reference = OrderedJSON.object([("$item", .string("title"))])
            if let index = dynamicProps.firstIndex(where: { $0.0 == field }) {
                dynamicProps[index].1 = reference
            } else {
                dynamicProps.append((field, reference))
            }
        }
        appendExample(&lines, first: first, firstProps, second: second, secondProps, dynamicProps)
        appendStateSections(&lines, first: first, firstProps)
        appendComponents(&lines)
        let hasActions = appendActions(&lines, options: options)
        appendEventsAndVisibility(&lines, first: first, firstProps)
        appendDynamicProps(&lines)
        appendDirectives(&lines, options.directives ?? directives.definitions)
        appendValidation(&lines)
        if hasActions { appendWatchers(&lines) }
        if let modes = options.editModes, !modes.isEmpty {
            lines.append(EditInstructions.build(modes))
        }
        lines.append("RULES:")
        let rules = Catalog.baseRules(inline: inline) + defaultRules + options.customRules
        for (index, rule) in rules.enumerated() { lines.append("\(index + 1). \(rule)") }
        return lines.joined(separator: "\n")
    }

    // MARK: - Example props

    /// Upstream `getExampleProps`: the explicit example (ordered by prop fields, then by
    /// key), otherwise the required fields of the props schema.
    func examplePropsFor(_ definition: ComponentDefinition?) -> [(String, OrderedJSON)] {
        guard let definition else { return [] }
        if let example = definition.example, !example.isEmpty {
            let fields = definition.props.fieldNames.filter { example[$0] != nil }
            let rest = example.keys.filter { !fields.contains($0) }.sorted()
            return (fields + rest).compactMap { key in
                example[key].map { (key, OrderedJSON($0)) }
            }
        }
        return definition.props.orderedExample().members ?? []
    }

    /// The function names for the prompt: registration order, then unordered extras.
    var orderedFunctionNames: [String] {
        functionOrder.filter { functions[$0] != nil }
            + functions.keys.filter { !functionOrder.contains($0) }.sorted()
    }

    // MARK: - Sections

    private func appendOutputFormat(_ lines: inout [String], inline: Bool) {
        if inline {
            lines += [
                "OUTPUT FORMAT (text + JSONL, RFC 6902 JSON Patch):",
                "You respond conversationally. When generating UI, first write a brief explanation (1-3 sentences), then output JSONL patch lines wrapped in a ```spec code fence.",
                "The JSONL lines use RFC 6902 JSON Patch operations to build a UI tree. Always wrap them in a ```spec fence block:",
                "  ```spec",
                #"  {"op":"add","path":"/root","value":"main"}"#,
                #"  {"op":"add","path":"/elements/main","value":{"type":"Card","props":{"title":"Hello"},"children":[]}}"#,
                "  ```",
                "If the user's message does not require a UI (e.g. a greeting or clarifying question), respond with text only — no JSONL.",
            ]
        } else {
            lines += [
                "OUTPUT FORMAT (JSONL, RFC 6902 JSON Patch):",
                "Output JSONL (one JSON object per line) using RFC 6902 JSON Patch operations to build a UI tree.",
            ]
        }
        lines += [
            "Each line is a JSON patch operation (add, remove, replace). Start with /root, then stream /elements and /state patches interleaved so the UI fills in progressively as it streams.",
            "",
            "Example output (each line is a separate JSON object):",
            "",
        ]
    }

    private func appendExample(
        _ lines: inout [String], first: String, _ firstProps: [(String, OrderedJSON)],
        second: String, _ secondProps: [(String, OrderedJSON)],
        _ dynamicProps: [(String, OrderedJSON)]
    ) {
        func add(_ path: String, _ value: OrderedJSON) -> String {
            OrderedJSON.object([
                ("op", .string("add")), ("path", .string(path)), ("value", value),
            ]).stringified
        }
        func ids(_ values: [String]) -> OrderedJSON { .array(values.map(OrderedJSON.string)) }
        let example = [
            add("/root", .string("main")),
            add(
                "/elements/main",
                .object([
                    ("type", .string(first)), ("props", .object(firstProps)),
                    ("children", ids(["child-1", "list"])),
                ])),
            add(
                "/elements/child-1",
                .object([
                    ("type", .string(second)), ("props", .object(secondProps)),
                    ("children", ids([])),
                ])),
            add(
                "/elements/list",
                .object([
                    ("type", .string(first)), ("props", .object(firstProps)),
                    (
                        "repeat",
                        .object([("statePath", .string("/items")), ("key", .string("id"))])
                    ),
                    ("children", ids(["item"])),
                ])),
            add(
                "/elements/item",
                .object([
                    ("type", .string(second)), ("props", .object(dynamicProps)),
                    ("children", ids([])),
                ])),
            add("/state/items", .array([])),
            add(
                "/state/items/0",
                .object([("id", .string("1")), ("title", .string("First Item"))])),
            add(
                "/state/items/1",
                .object([("id", .string("2")), ("title", .string("Second Item"))])),
        ].joined(separator: "\n")
        lines.append(
            example
                + "\n\nNote: state patches appear right after the elements that use them, so the UI fills in as it streams. ONLY use component types from the AVAILABLE COMPONENTS list below."
        )
        lines.append("")
    }

    private func appendStateSections(
        _ lines: inout [String], first: String, _ firstProps: [(String, OrderedJSON)]
    ) {
        let repeatExample = OrderedJSON.object([
            ("type", .string(first)), ("props", .object(firstProps)),
            ("repeat", .object([("statePath", .string("/todos")), ("key", .string("id"))])),
            ("children", .array([.string("todo-item")])),
        ]).stringified
        lines += [
            "INITIAL STATE:",
            "Specs include a /state field to seed the state model. Components with { $bindState } or { $bindItem } read from and write to this state, and $state expressions read from it.",
            "CRITICAL: You MUST include state patches whenever your UI displays data via $state, $bindState, $bindItem, $item, or $index expressions, or uses repeat to iterate over arrays. Without state, these references resolve to nothing and repeat lists render zero items.",
            "Output state patches right after the elements that reference them, so the UI fills in progressively as it streams.",
            "Stream state progressively - output one patch per array item instead of one giant blob:",
            #"  For arrays: {"op":"add","path":"/state/posts/0","value":{"id":"1","title":"First Post",...}} then /state/posts/1, /state/posts/2, etc."#,
            #"  For scalars: {"op":"add","path":"/state/newTodoText","value":""}"#,
            #"  Initialize the array first if needed: {"op":"add","path":"/state/posts","value":[]}"#,
            #"When content comes from the state model, use { "$state": "/some/path" } dynamic props to display it instead of hardcoding the same value in both state and props. The state model is the single source of truth."#,
            "Include realistic sample data in state. For blogs: 3-4 posts with titles, excerpts, authors, dates. For product lists: 3-5 items with names, prices, descriptions. Never leave arrays empty.",
            "",
            "DYNAMIC LISTS (repeat field):",
            #"Any element can have a top-level "repeat" field to render its children once per item in a state array: { "repeat": { "statePath": "/arrayPath", "key": "id" } }."#,
            #"The element itself renders once (as the container), and its children are expanded once per array item. "statePath" is the state array path. "key" is an optional field name on each item for stable React keys."#,
            #"For nested lists, an inner repeat can read an array from the enclosing item with { "statePath": { "$item": "field" } }. This form is valid only inside another repeat. Use an empty field to repeat over the enclosing item itself."#,
            "Example: \(repeatExample)",
            #"Inside children of a repeated element, use { "$item": "field" } to read a field from the current item, and { "$index": true } to get the current array index. For two-way binding to an item field use { "$bindItem": "completed" } on the appropriate prop."#,
            "ALWAYS use the repeat field for lists backed by state arrays. NEVER hardcode individual elements for each array item.",
            #"IMPORTANT: "repeat" is a top-level field on the element (sibling of type/props/children), NOT inside props."#,
            "",
            "ARRAY STATE ACTIONS:",
            #"Use action "pushState" to append items to arrays. Params: { statePath: "/arrayPath", value: { ...item }, clearStatePath: "/inputPath" }."#,
            #"Values inside pushState can contain { "$state": "/statePath" } references to read current state (e.g. the text from an input field)."#,
            #"Use "$id" inside a pushState value to auto-generate a unique ID."#,
            #"Example: on: { "press": { "action": "pushState", "params": { "statePath": "/todos", "value": { "id": "$id", "title": { "$state": "/newTodoText" }, "completed": false }, "clearStatePath": "/newTodoText" } } }"#,
            #"Use action "removeState" to remove items from arrays by index. Params: { statePath: "/arrayPath", index: N }. Inside a repeated element's children, use { "$index": true } for the current item index. Action params support the same expressions as props: { "$item": "field" } resolves to the absolute state path, { "$index": true } resolves to the index number, and { "$state": "/path" } reads a value from state."#,
            "For lists where users can add/remove items (todos, carts, etc.), use pushState and removeState instead of hardcoding with setState.",
            "",
            #"IMPORTANT: State paths use RFC 6901 JSON Pointer syntax (e.g. "/todos/0/title"). Do NOT use JavaScript-style dot notation (e.g. "/todos.length" is WRONG). To generate unique IDs for new items, use "$id" instead of trying to read array length."#,
            "",
        ]
    }

    private func appendComponents(_ lines: inout [String]) {
        lines.append("AVAILABLE COMPONENTS (\(components.count)):")
        lines.append("")
        for definition in components {
            let named = definition.slots.filter { $0 != "default" }
            let slotText = [
                definition.acceptsChildren ? "accepts children" : "",
                named.isEmpty ? "" : "slots: \(named.joined(separator: ", "))",
            ].filter { !$0.isEmpty }.joined(separator: "; ")
            let slots = slotText.isEmpty ? "" : " [\(slotText)]"
            let events =
                definition.events.isEmpty
                ? "" : " [events: \(definition.events.joined(separator: ", "))]"
            let description = definition.description.isEmpty ? "" : " - \(definition.description)"
            lines.append(
                "- \(definition.name): \(definition.props.formatted())\(description)\(slots)\(events)"
            )
        }
        lines.append("")
    }

    /// Returns whether any action (built-in, extension or custom) was listed.
    private func appendActions(_ lines: inout [String], options: PromptOptions) -> Bool {
        let extensions = options.includeExtensions ? extensionActions : []
        let custom = actionOrder.filter { actions[$0] != nil }
        guard !builtInActions.isEmpty || !extensions.isEmpty || !custom.isEmpty else {
            return false
        }
        lines.append("AVAILABLE ACTIONS:")
        lines.append("")
        for action in builtInActions + extensions {
            lines.append("- \(action.name): \(action.description) [built-in]")
        }
        for name in custom {
            let description = actions[name]?.description ?? ""
            lines.append(description.isEmpty ? "- \(name)" : "- \(name): \(description)")
        }
        lines.append("")
        return true
    }

    private func appendEventsAndVisibility(
        _ lines: inout [String], first: String, _ firstProps: [(String, OrderedJSON)]
    ) {
        let eventExample = OrderedJSON.object([
            ("type", .string(first)), ("props", .object(firstProps)),
            (
                "on",
                .object([
                    (
                        "press",
                        .object([
                            ("action", .string("setState")),
                            (
                                "params",
                                .object([
                                    ("statePath", .string("/saved")), ("value", .bool(true)),
                                ])
                            ),
                        ])
                    )
                ])
            ),
            ("children", .array([])),
        ]).stringified
        let visibleExample = OrderedJSON.object([
            ("type", .string(first)), ("props", .object(firstProps)),
            ("visible", .object([("$state", .string("/activeTab")), ("eq", .string("home"))])),
            ("children", .array([.string("...")])),
        ]).stringified
        lines += [
            "EVENTS (the `on` field):",
            "Elements can have an optional `on` field to bind events to actions. The `on` field is a top-level field on the element (sibling of type/props/children), NOT inside props.",
            #"Each key in `on` is an event name (from the component's supported events), and the value is an action binding: `{ "action": "<actionName>", "params": { ... } }`."#,
            "",
            "Example:",
            "  \(eventExample)",
            "",
            #"Action params can use dynamic references to read from state: { "$state": "/statePath" }."#,
            "IMPORTANT: Do NOT put action/actionParams inside props. Always use the `on` field for event bindings.",
            "",
            "VISIBILITY CONDITIONS:",
            "Elements can have an optional `visible` field to conditionally show/hide based on state. IMPORTANT: `visible` is a top-level field on the element object (sibling of type/props/children), NOT inside props.",
            "Correct: \(visibleExample)",
            #"- `{ "$state": "/path" }` - visible when state at path is truthy"#,
            #"- `{ "$state": "/path", "not": true }` - visible when state at path is falsy"#,
            #"- `{ "$state": "/path", "eq": "value" }` - visible when state equals value"#,
            #"- `{ "$state": "/path", "neq": "value" }` - visible when state does not equal value"#,
            #"- `{ "$state": "/path", "gt": N }` / `gte` / `lt` / `lte` - numeric comparisons"#,
            "- Use ONE operator per condition (eq, neq, gt, gte, lt, lte). Do not combine multiple operators.",
            #"- Any condition can add `"not": true` to invert its result"#,
            "- `[condition, condition]` - all conditions must be true (implicit AND)",
            #"- `{ "$and": [condition, condition] }` - explicit AND (use when nesting inside $or)"#,
            #"- `{ "$or": [condition, condition] }` - at least one must be true (OR)"#,
            "- `true` / `false` - always visible/hidden",
            "",
            "Use a component with on.press bound to setState to update state and drive visibility.",
            #"Example: A \#(first) with on: { "press": { "action": "setState", "params": { "statePath": "/activeTab", "value": "home" } } } sets state, then a container with visible: { "$state": "/activeTab", "eq": "home" } shows only when that tab is active."#,
            "",
            #"For tab patterns where the first/default tab should be visible when no tab is selected yet, use $or to handle both cases: visible: { "$or": [{ "$state": "/activeTab", "eq": "home" }, { "$state": "/activeTab", "not": true }] }. This ensures the first tab is visible both when explicitly selected AND when /activeTab is not yet set."#,
            "",
        ]
    }

    private func appendDynamicProps(_ lines: inout [String]) {
        lines += [
            "DYNAMIC PROPS:",
            "Any prop value can be a dynamic expression that resolves based on state. Three forms are supported:",
            "",
            #"1. Read-only state: `{ "$state": "/statePath" }` - resolves to the value at that state path (one-way read)."#,
            #"   Example: `"color": { "$state": "/theme/primary" }` reads the color from state."#,
            "",
            #"2. Two-way binding: `{ "$bindState": "/statePath" }` - resolves to the value at the state path AND enables write-back. Use on form input props (value, checked, pressed, etc.)."#,
            #"   Example: `"value": { "$bindState": "/form/email" }` binds the input value to /form/email."#,
            #"   Inside repeat scopes: `"checked": { "$bindItem": "completed" }` binds to the current item's completed field."#,
            "",
            #"3. Conditional: `{ "$cond": <condition>, "$then": <value>, "$else": <value> }` - evaluates the condition (same syntax as visibility conditions) and picks the matching value."#,
            ##"   Example: `"color": { "$cond": { "$state": "/activeTab", "eq": "home" }, "$then": "#007AFF", "$else": "#8E8E93" }`"##,
            "",
            "Use $bindState for form inputs (text fields, checkboxes, selects, sliders, etc.) and $state for read-only data display. Inside repeat scopes, use $bindItem for form inputs bound to the current item. Use dynamic props instead of duplicating elements with opposing visible conditions when only prop values differ.",
            "",
            #"4. Template: `{ "$template": "Hello, ${/name}!" }` - interpolates references in the string. Absolute paths like `${/path}` resolve against the state model. Bare names like `${field}` resolve against the current repeat item first, then fall back to the state model at `/<field>`."#,
            #"   Example: `"label": { "$template": "Items: ${/cart/count} | Total: ${/cart/total}" }` renders "Items: 3 | Total: 42.00" when /cart/count is 3 and /cart/total is 42.00. Inside a repeat, `{ "$template": "${name} - ${email}" }` reads name and email from each item."#,
            "",
        ]
        let names = orderedFunctionNames
        guard !names.isEmpty else { return }
        lines += [
            #"5. Computed: `{ "$computed": "<functionName>", "args": { "key": <expression> } }` - calls a registered function with resolved args and returns the result."#,
            #"   Example: `"value": { "$computed": "fullName", "args": { "first": { "$state": "/form/firstName" }, "last": { "$state": "/form/lastName" } } }`"#,
            "   Available functions:",
        ]
        for name in names {
            let description = functionDescriptions[name] ?? ""
            lines.append(description.isEmpty ? "   - \(name)" : "   - \(name) — \(description)")
        }
        lines.append("")
    }

    private func appendDirectives(_ lines: inout [String], _ definitions: [DirectiveDefinition]) {
        guard !definitions.isEmpty else { return }
        lines += ["CUSTOM DYNAMIC VALUES:", ""]
        for definition in definitions {
            let description = definition.description.map { " (\($0))" } ?? ""
            lines.append("- \(definition.name)\(description): \(definition.schema.formatted())")
        }
        lines += [
            "",
            "Directives compose: any value field can contain another directive or a $state expression, resolved inside-out.",
            "",
        ]
    }

    private func appendValidation(_ lines: inout [String]) {
        guard components.contains(where: { $0.props.formatted().contains("checks") }) else {
            return
        }
        lines += [
            "VALIDATION:",
            "Form components that accept a `checks` prop support client-side validation.",
            #"Each check is an object: { "type": "<name>", "message": "...", "args": { ... } }"#,
            "",
            "Built-in validation types:",
        ]
        lines += BuiltInValidation.promptLines
        for name in validators.keys.sorted() where BuiltInValidation.functions[name] == nil {
            let description = validators[name]?.description ?? ""
            lines.append(description.isEmpty ? "  - \(name)" : "  - \(name) — \(description)")
        }
        lines += [
            "",
            "Example:",
            #"  "checks": [{ "type": "required", "message": "Email is required" }, { "type": "email", "message": "Invalid email" }]"#,
            "",
            "IMPORTANT: When using checks, the component must also have a { $bindState } or { $bindItem } on its value/checked prop for two-way binding.",
            "Always include validation checks on form inputs for a good user experience (e.g. required, email, minLength).",
            "",
        ]
    }

    private func appendWatchers(_ lines: inout [String]) {
        lines += [
            "STATE WATCHERS:",
            "Elements can have an optional `watch` field to react to state changes and trigger actions. The `watch` field is a top-level field on the element (sibling of type/props/children), NOT inside props.",
            "Maps state paths (JSON Pointers) to action bindings. When the value at a watched path changes, the bound actions fire automatically.",
            "",
            "Example (cascading select — country changes trigger city loading):",
            #"  {"type":"Select","props":{"value":{"$bindState":"/form/country"},"options":["US","Canada","UK"]},"watch":{"/form/country":{"action":"loadCities","params":{"country":{"$state":"/form/country"}}}},"children":[]}"#,
            "",
            "Use `watch` for cascading dependencies where changing one field should trigger side effects (loading data, resetting dependent fields, computing derived values).",
            "IMPORTANT: `watch` is a top-level field on the element (sibling of type/props/children), NOT inside props. Watchers only fire when the value changes, not on initial render.",
            "",
        ]
    }

    static func baseRules(inline: Bool) -> [String] {
        let shared = [
            #"First set root: {"op":"add","path":"/root","value":"<root-key>"}"#,
            #"Then add each element: {"op":"add","path":"/elements/<key>","value":{...}}"#,
            "Output /state patches right after the elements that use them, one per array item for progressive loading. REQUIRED whenever using $state, $bindState, $bindItem, $item, $index, or repeat.",
            "ONLY use components listed above",
            "Each element value needs: type, props, children (array of child keys)",
            "Use unique keys for the element map entries (e.g., 'header', 'metric-1', 'chart-revenue')",
        ]
        if inline {
            return [
                "When generating UI, wrap all JSONL patches in a ```spec code fence - one JSON object per line inside the fence",
                "Write a brief conversational response before any JSONL output",
            ] + shared
        }
        return [
            "Output ONLY JSONL patches - one JSON object per line, no markdown, no code fences"
        ] + shared
    }
}
