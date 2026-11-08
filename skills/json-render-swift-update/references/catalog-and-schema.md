# Catalog, prompt and JSON Schema

Contents: PropSchema, formatted(), prompt() sections, extension lines, jsonSchema, prompt parity, validation rules, how to add a directive, a $computed function, an action, a validator or a rule.

All of this is in `Sources/JSONRenderCore/Catalog/` and is Foundation only. A change here moves the text every model sees, so it needs a parity decision (see below).

## PropSchema

`PropSchema` mirrors the zod shapes upstream uses, with a `kind`, `isOptional` (zod `.optional()`), `isNullable` (`.nullable()`) and a `description`.

| Kind | Builder | `formatted()` |
|---|---|---|
| string, number, boolean | `.string`, `.number`, `.boolean` | `string`, `number`, `boolean` |
| any | `.any` | `unknown` |
| enum | `.enum(["a","b"])` | `"a" \| "b"` |
| array | `.array(element)` | `Array<string>` |
| object | `.object([Field(name:schema:description:)])` | `{ title: string, subtitle?: string }` |
| record | `.record(value)` | `Record<string, unknown>` |
| literal | `.literal(value)` | the JSON text |
| union | `.union([a, b])` | `a \| b` |

Modifiers: `.optional()`, `.nullable()`, `.described("...")`. A field that is optional or nullable prints with `?`. Field order is the prompt order.

Other tools on a schema: `validate(_:at:)` returns `[PropIssue]` (path and message, never the value), `exampleValue()` builds example props, `jsonSchema(strict:)` and `jsonSchemaText(strict:)` print JSON Schema.

## prompt() sections, in order

`Catalog.prompt(PromptOptions)` writes, in this order (a section is skipped when it has nothing to say):

1. The system line, then OUTPUT FORMAT with a generated example (first two components).
2. INITIAL STATE, DYNAMIC LISTS (repeat), ARRAY STATE ACTIONS.
3. AVAILABLE COMPONENTS (N): one line per component: `- Name: { props } - description [accepts children] [events: ...]`.
4. AVAILABLE ACTIONS: the four upstream built-ins, then (when `includeExtensions` is true) `toggleState` and `incrementState`, all marked `[built-in]`, then the catalog actions.
5. EVENTS (the `on` field) and VISIBILITY CONDITIONS.
6. DYNAMIC PROPS: items 1 to 4 always; item 5 (`$computed` with "Available functions", `name — description`) only when functions are registered.
7. CUSTOM DYNAMIC VALUES: the directives, if any.
8. VALIDATION: when a component has a `checks` prop; custom validators follow the built-in types.
9. STATE WATCHERS: when there are actions.
10. EDITING EXISTING SPECS: only with `editModes`.
11. RULES: base rules (mode-dependent), then `defaultRules`, then `customRules`.

Modes: `.standalone` (JSONL only) and `.inline` (prose, then a `spec` fence).

## Extension lines (not upstream)

With `includeExtensions: false` and a catalog built like the upstream one, the text equals upstream byte for byte. These are the additions:

- The extension actions (`toggleState`, `incrementState`).
- `$computed` function descriptions (`name — description`).
- Custom validators listed after the built-in validation types.
- Component events and slots on the Swift components, and the props marked `+`.

Keep every addition on its own line or section so a diff against upstream stays small.

## jsonSchema(strict:)

`Catalog.jsonSchema(strict:)` and `jsonSchemaText(strict:)` print the spec's JSON Schema in upstream key order. Strict mode reproduces upstream, including its limit: records are opaque, so `elements` admits no keys and a structured-output call cannot fill it. Say so wherever the strict schema is offered, and point to the prompt plus object mode instead. Loose mode carries the element `type` enum.

## Parity diff

`Tests/JSONRenderCoreTests/PromptParityTests.swift` compares `prompt()` byte for byte with `Tests/ParityFixtures/upstream/prompt/*.txt` (shadcn standalone, shadcn inline, a minimal two-component catalog), with `includeExtensions: false`. The schema fixtures are compared the same way. The test prints the differing lines. Rules:

- A change that moves a fixture line is a bug unless the upstream pin moved too.
- Never edit `Tests/ParityFixtures/upstream/**`. To test new text, add a sibling fixture folder.
- The standard catalog's component lines must equal upstream after removing the `+` props (`StandardCatalogPromptTests`).

## Add a directive

```swift
var catalog = Catalog()
let double = try DirectiveDefinition(
    name: "$double", description: "Double a number.",
    schema: .object([.init(name: "$double", schema: .any)])
) { value, resolver in
    guard let operand = value["$double"], let resolved = resolver.resolveValue(operand),
        let number = resolved.numberValue
    else { return nil }
    return .number(number * 2)
}
catalog.directive(double)
```

- The name starts with `$` and is not a built-in key (`$state`, `$item`, `$index`, `$bindState`, `$bindItem`, `$cond`, `$computed`, `$template`); the init throws `DirectiveError` otherwise.
- Resolve operands with `resolver.resolveValue(_:)` so directives compose.
- The shipped four (`$format`, `$count`, `$join`, `$pluralize`) live in `Sources/JSONRenderStandardCatalog/Directives/StandardDirectives.swift` and match upstream output.
- Fixtures: add expression cases in a sibling folder; the schema must match the zod shape so the prompt lists it under CUSTOM DYNAMIC VALUES.

## Add a $computed function, action, validator or rule

```swift
var catalog = Catalog()
catalog.function("topN", description: "Keep the n largest rows") { args in
    nil  // args is [String: JSONValue?]; return JSONValue?
}
catalog.action(
    "open_file", params: .object([.init(name: "path", schema: .string)]),
    description: "Open a file in the editor"
) { params, host in nil }
catalog.validator("startsWithA", description: "Starts with A") { value, args in
    value?.stringValue?.hasPrefix("A") ?? false
}
catalog.rule("my-rule") { spec, state in [] }
```

- Missing or wrong-typed args give `nil` (undefined). Never trap, never log values.
- A name registered twice in one catalog replaces; `merging(_:)` throws `duplicate...` for a name in both.
- Rules run in registration order in `Catalog.validate` after the built-in passes. Issue messages carry ids and rule text only.
- Actions without a handler are declarations for the prompt; the host supplies the handler.
- Specs carry no code. A new capability is a registered Swift closure, named by the spec.

## Dictionary order

Never iterate a `[String: JSONValue]` unsorted when you produce output, ids or issue lists. Sort keys first. Output must be deterministic.
