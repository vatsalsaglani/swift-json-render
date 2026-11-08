# Add or change a standard component

Contents: decide the contract, the file, the macro, the style protocol, slots and events, accessibility, registration, tests, the end of the chain.

A standard component is one SwiftUI view that reads a `JRRenderContext`, plus its catalog definition. Upstream shadcn names and prop names are the base: a spec written for the upstream shadcn catalog must render with no change. Extra props marked `+` in the plan are optional.

## 1. Decide the contract first

- Name and props: take them from upstream `packages/shadcn/src/catalog.ts` (`Tests/ParityFixtures/upstream/prompt/catalogs.json` holds them). Keep the upstream names, types, optionality and the description text. Append one sentence to the description only when an extra prop needs it.
- Three to five props. Only the content prop is required. No colour, font or size props; the theme decides. Variants are enum values the spec can pick; the theme decides how each looks.
- Slots: `default` means `children`. Other slots: `header`, `footer`, `leading`, `trailing`, `empty`, `loading`, `error`.
- Events: only what the component really emits (`press`, `change`, `select`, `submit`, `focus`, `blur`).
- Write the prop table into the plan or the PR text before you code. Update `skills/json-render-swift-use/references/components.md` (see "End of the chain").

## 2. The file

One file per component in `Sources/JSONRenderStandardCatalog/Components/<Name>.swift`. It holds the view, the style protocol, the configuration, the default style, the environment entry and the modifier.

```swift
import JSONRenderClient
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

@JRComponent("Callout", description: "A short note with a title.", slots: ["default"])
struct JRCallout: View {
    @JRProp(description: "Heading line") var title: String
    @JRProp(description: "Tone of the note", oneOf: ["info", "warning"]) var tone: String = "info"

    @Environment(\.jsonRenderTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.space.s2) {
            Text(title).font(theme.type.bodyEmphasis)
            jrContext.children
        }
        .padding(theme.space.s3)
    }
}
```

- The Swift type is named `JR<Name>` (`JRCard`, `JRLink`); the macro takes the catalog name from its first argument. `@JRComponent` generates `static let definition`, `jrContext`, `init(context:)` and the `JRComponentType` conformance. Use it for every component.
- `JRComponentType` is not `Sendable`. Never mark a view `@unchecked Sendable`.
- Read props from the generated properties. Read raw values with `jrContext.prop("name")` (`JSONValue?`).
- Never put a document's text or state value into a log, an issue message or an accessibility identifier.
- The view must be cheap in `body`: no sorting, no parsing, no formatting of large data. Do that in a pure function you can unit test, outside the view.

## 3. What the macro supports

| Swift type | Schema | Default when missing |
|---|---|---|
| `String` | `string` | `""` |
| `Double`, `Float`, `CGFloat`, `Int` (rounded) | `number` | `0` |
| `Bool` | `boolean` | `false` |
| `JSONValue` | `any` | `.null` |
| `[T]` of the above | `array(T)` | `[]` |
| `T?` | nullable | `nil` |

- A default value (`var tone: String = "info"`) makes the prop optional in the schema. Use `var`, not `let`, with a default.
- `@JRProp(oneOf:)` works on `String` and `String?` only; the schema becomes an enum.
- `@JRProp(bindable: true)` documents `$bindState`. `@JRProp(secret: true)` lists the prop in `ComponentDefinition.secretProps`; hosts must not persist or log it.
- A list of objects (tabs, rows, items) is `[JSONValue]`. Decode the elements in the view, in a pure helper with a test for missing and `null` fields.
- Diagnostics: not a struct, missing name, computed property, missing type, `let` with a default, unsupported type, `oneOf` on a non-String, duplicate prop name.
- The prop order in the definition is declaration order, and it is the order the prompt prints. Match upstream order.

## 4. Style protocol pattern

Every component gets a style protocol shaped like `ButtonStyle`, so an app can restyle it without touching behaviour.

```swift
import JSONRender
import SwiftUI

public protocol JRCalloutStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRCalloutStyleConfiguration) -> Body
}

public struct JRCalloutStyleConfiguration {
    public let title: Text
    public let content: JRStyleContent
    public let theme: JSONRenderTheme
    public let isStreaming: Bool
}

public struct DefaultJRCalloutStyle: JRCalloutStyle {
    public init() {}

    public func makeBody(configuration: JRCalloutStyleConfiguration) -> some View {
        VStack(alignment: .leading, spacing: configuration.theme.space.s2) {
            configuration.title.font(configuration.theme.type.bodyEmphasis)
            configuration.content
        }
        .padding(configuration.theme.space.s3)
    }
}

extension EnvironmentValues {
    @Entry public var jrCalloutStyle: any JRCalloutStyle = DefaultJRCalloutStyle()
}

extension View {
    public func jrCalloutStyle(_ style: some JRCalloutStyle) -> some View {
        environment(\.jrCalloutStyle, style)
    }
}
```

The view then draws `JRStyleContent(style.makeBody(configuration: configuration))`; see `Components/Link.swift` for the whole pattern. `JRStyleContent` (in `JSONRenderSwiftUI`) is the type-erasing wrapper for a child region and for the style's result.

Rules:

- The configuration carries resolved props, label views, state flags and the theme. It never carries the store, a binding writer or `emit`. A style can change looks, not behaviour.
- The focus ring is drawn by the configuration's content, so a style can move it but not remove it.
- `AnyView` is allowed only at the registry boundary (`ViewFactory`) and inside `JRStyleContent`. Do not scatter it.
- The default style reads only theme tokens. No hard-coded colours, radii or fonts. No shadow inside a card. A hairline only where a surface starts.
- Environment entries hold `Equatable` structs, never a bare closure. Give a new `id` only when the function really changes.

## 5. Slots, children and events

- Children: `jrContext.children` (a `JRChildren`, which is a `View`). Named slot: `jrContext.slots["footer"]`; draw it only when present.
- Emit an event: `jrContext.emit("press", [:])`. The renderer runs the element's `on[event]` bindings. Do not run actions in the view.
- Bound value: `jrContext.bindings["value"]` is the `JSONPointer` of a `$bindState` or `$bindItem`. Write through the environment's `jrWriteBinding(pointer, value)`; do not talk to the store.
- A bound input publishes one store commit per change. Keep it that way.
- `isStreaming` (or the `jrStreamPhase` environment value) selects skeleton or stopped states. A missing child draws as a static placeholder that holds the final layout. No spinner, no shimmer.

## 6. Accessibility (every component)

- Label from props (`label`, `title`, `text`, `alt`, `name`). Every control has a label VoiceOver can read.
- `Heading` adds the header trait. Progress and Slider expose their value. Table rows read their cells.
- Visible focus ring in `theme.color.focus`; tab order follows children order.
- Reduce Motion: no fade and no pulse. Increase Contrast: 2 pt hairline, muted text becomes secondary. Text size follows `controlSize` from `size`.
- Status is an icon, a word and a hue. Never colour alone.

## 7. Register it

Add the type to the group file, in prompt order (the list order is the prompt order):

```swift
// not compiled: the group files are internal to JSONRenderStandardCatalog
// Sources/JSONRenderStandardCatalog/StandardEntries+Group1.swift (group 2 is in StandardEntries+Group2.swift)
static let group1: [ComponentDefinition] = [JRCard.definition, JRStack.definition /* ... */]

static func registerGroup1(into catalog: inout Catalog) throws(CatalogError) {
    try catalog.register(JRCard.self)
    try catalog.register(JRStack.self)
    // ...
}
```

A component whose object-list props need a spelled-out schema (`Tabs`, `Accordion`, `Table`, `DropdownMenu`) lists `catalogDefinition` instead of `definition`.

`Catalog.register<C: View & JRComponentType>(_:)` is not main-actor; the view is built only inside the `@MainActor` factory closure. A duplicate name throws `duplicateComponent`. `StandardEntries.components` sums the groups; do not edit `StandardEntries.swift`.

## 8. Tests to add

- A definition test: name, prop names and order, `props.formatted()` for the component, slots, events, `secretProps`.
- A prompt test: the formatted props line equals the upstream line after the `+` props are removed (`StandardCatalogPromptTests` pattern). This is the drift guard.
- Props decoding: missing, `null`, wrong type and enum edge cases, on the pure helper.
- Behaviour that is not a view: bound value commits, emitted events, visibility. Prefer the model layer; avoid view-tree tests.
- The invariance suite script (see `tests.md`): add an interaction for the component if it emits events or binds state.
- A fixture spec if the component has semantics (a new directive, a binding rule, a repeat form). See `parity.md`.

## End of the chain

1. Gallery page: a page that shows every variant in a Card (`GalleryPage`, `Examples/Gallery/Sources/Gallery/`), and its line in `GalleryPages.all`.
2. Regenerate the use skill's component list: `skills/scripts/refresh-catalog-reference.sh`, then update the notes in `skills/json-render-swift-use/references/components.md` (extras, slots, events, binding prop) and `skills/scripts/check-skills.sh`.
3. Refresh the site data (`release.md`), add a CHANGELOG line, and report the test counts and any prompt text change.
