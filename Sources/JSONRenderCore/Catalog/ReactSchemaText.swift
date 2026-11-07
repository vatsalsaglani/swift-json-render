/// A built-in action as the prompt lists it.
public struct BuiltInActionDescription: Sendable, Hashable {
    public var name: String
    public var description: String

    public init(name: String, description: String) {
        self.name = name
        self.description = description
    }
}

/// Verbatim text from upstream `react/src/schema.ts` (json-render 0.22.0): the built-in
/// action descriptions and the schema's default rules. Prompt parity depends on every byte.
public enum ReactSchemaText {
    /// The four upstream built-in actions, in upstream order.
    public static let builtInActions: [BuiltInActionDescription] = [
        BuiltInActionDescription(
            name: "setState",
            description:
                "Update a value in the state model at the given statePath. Params: { statePath: string, value: any }"
        ),
        BuiltInActionDescription(
            name: "pushState",
            description:
                "Append an item to an array in state. Params: { statePath: string, value: any, clearStatePath?: string }. Value can contain {\"$state\":\"/path\"} refs and \"$id\" for auto IDs."
        ),
        BuiltInActionDescription(
            name: "removeState",
            description:
                "Remove an item from an array in state by index. Params: { statePath: string, index: number }"
        ),
        BuiltInActionDescription(
            name: "validateForm",
            description:
                "Validate all registered form fields and write the result to state. Params: { statePath?: string }. Defaults to /formValidation. Result: { valid: boolean, errors: Record<string, string[]> }."
        ),
    ]

    /// The Swift extension actions (`toggleState`, `incrementState`). Not upstream text.
    public static let extensionActions: [BuiltInActionDescription] = [
        BuiltInActionDescription(
            name: "toggleState",
            description:
                "Flip a boolean in state. Params: { statePath: string }. A missing or null value becomes true."
        ),
        BuiltInActionDescription(
            name: "incrementState",
            description:
                "Add a number to a numeric value in state. Params: { statePath: string, by?: number }. by defaults to 1; a missing value counts as 0."
        ),
    ]

    /// The React schema `defaultRules`, in upstream order.
    public static let defaultRules: [String] = [
        "CRITICAL INTEGRITY CHECK: Before outputting ANY element that references children, you MUST have already output (or will output) each child as its own element. If an element has children: ['a', 'b'], then elements 'a' and 'b' MUST exist. A missing child element causes that entire branch of the UI to be invisible.",
        "SELF-CHECK: After generating all elements, mentally walk the tree from root. Every key in every children array must resolve to a defined element. If you find a gap, output the missing element immediately.",
        "REQUIRED FIELDS: Every element MUST include a \"children\" array. Leaf elements (text, badges, inputs, images) use an empty array: \"children\": []. Omitting \"children\" fails validation.",
        "NAMED SLOTS: Use \"children\" for the default slot. For other slots declared by the component, use a top-level \"slots\" object that maps each slot name to child element keys, for example {\"slots\":{\"header\":[\"heading\"],\"footer\":[\"actions\"]}}. Never use \"slots.default\". Every referenced key must exist.",
        "FILTERED LISTS: To render only the items matching a field value (kanban columns, tabbed lists, status sections), put \"repeat\" and a \"visible\" condition with $item on the same container element: {\"repeat\": {\"statePath\": \"/tasks\", \"key\": \"id\"}, \"visible\": {\"$item\": \"status\", \"eq\": \"todo\"}} renders one child per matching item. A visible condition object must use exactly one of $state, $item, or $index — never combine them in one object.",
        "CRITICAL: The \"visible\" field goes on the ELEMENT object, NOT inside \"props\". Correct: {\"type\":\"<ComponentName>\",\"props\":{},\"visible\":{\"$state\":\"/tab\",\"eq\":\"home\"},\"children\":[...]}.",
        "CRITICAL: The \"on\" field goes on the ELEMENT object, NOT inside \"props\". Use on.press, on.change, on.submit etc. NEVER put action/actionParams inside props.",
        "When the user asks for a UI that displays data (e.g. blog posts, products, users), ALWAYS include a state field with realistic sample data. The state field is a top-level field on the spec (sibling of root/elements).",
        "When building repeating content backed by a state array (e.g. posts, products, items), use the \"repeat\" field on a container element. Example: { \"type\": \"<ContainerComponent>\", \"props\": {}, \"repeat\": { \"statePath\": \"/posts\", \"key\": \"id\" }, \"children\": [\"post-card\"] }. For a nested list stored on the enclosing item, use \"repeat\": { \"statePath\": { \"$item\": \"comments\" }, \"key\": \"id\" }. The $item statePath form is valid only inside another repeat. Replace <ContainerComponent> with an appropriate component from the AVAILABLE COMPONENTS list. Inside repeated children, use { \"$item\": \"field\" } to read a field from the current item, and { \"$index\": true } for the current array index. For two-way binding to an item field use { \"$bindItem\": \"completed\" }. Do NOT hardcode individual elements for each array item.",
        "Design with visual hierarchy: use container components to group content, heading components for section titles, proper spacing, and status indicators. ONLY use components from the AVAILABLE COMPONENTS list.",
        "For data-rich UIs, use multi-column layout components if available. For forms and single-column content, use vertical layout components. ONLY use components from the AVAILABLE COMPONENTS list.",
        "Always include realistic, professional-looking sample data. For blogs include 3-4 posts with varied titles, authors, dates, categories. For products include names, prices, images. Never leave data empty.",
    ]
}
