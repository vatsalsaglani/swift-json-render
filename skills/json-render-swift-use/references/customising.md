# Customising from the host

Contents: the six layers, theme tokens, variants, style hooks, slots, override, custom components, actions, functions, directives and rules.

Rule: customisation never changes semantics. The same spec gives the same state changes and the same emitted actions with any theme, any style hook, and any view that replaces a component. Start at layer a; go down only when the layer above cannot do it.

| Layer | Changes | Use it for |
|---|---|---|
| a. Theme tokens | colour roles, type scale, spacing, radius, elevation, motion, chart tokens | brand and density |
| b. Variants | looks the catalog declares and the spec selects | `variant`, `size` props |
| c. Style hooks | a SwiftUI style protocol per component | a different Card or Table look |
| d. Slots | named child regions | header, footer, empty, error |
| e. View replacement | one component type, same props and actions | a custom Table |
| f. Custom components and actions | new types | domain components |

## a. Theme tokens

`JSONRenderTheme` has `color`, `type`, `space`, `radius`, `elevation`, `motion` and `charts`. The default is `.native` (system colours, light and dark, Increase Contrast, Dynamic Type). Change a copy and put it in the environment:

```swift
import JSONRenderSwiftUI
import SwiftUI

func brandTheme() -> JSONRenderTheme {
    var theme = JSONRenderTheme.native
    theme.radius.card = 6
    theme.space.s3 = 14
    theme.color.accent = .indigo
    return theme
}

struct Themed<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content.environment(\.jsonRenderTheme, brandTheme())
    }
}
```

Token groups: `ColorRoles` (surface, surfaceRaised, text, textSecondary, textMuted, hairline, accent, onAccent, good, warning, critical, info, focus), `TypeScale` (caption, footnote, body, bodyEmphasis, title, display, mono, weights), `SpaceScale` (s1 to s6), `RadiusScale` (control, field, card), `Elevation`, `Motion` (reveal, pulse), `ChartTokens`.

Keep contrast: text and secondary text 4.5:1, muted text 3:1, accent 3:1, on-accent 3:1. `try theme.validated()` throws `ThemeContrastError` with the failing pairs; `JSONRenderView` also audits each theme once (a debug build asserts, a release build logs role names only).

Three modifiers set a theme for a subtree: `.jsonRenderTheme(theme)` (the whole theme), `.jsonRenderTheme(\.radius.card, 6)` (one token) and `.jsonRenderTheme(theme, forTypes: ["Card"])` (a whole theme for the listed component types). Precedence: per-type theme beats per-token override beats whole theme. Presets: `.native` and `.highContrast`. Accent colour only on the primary Button, the active Tab, the Switch when on, Progress and the focus ring: do not spread it.

## b. Variants

The catalog declares looks and the spec picks one: Button `primary` / `secondary` / `danger`, Card `plain` / `outlined` / `elevated`, Badge, Text. The theme decides what each looks like. To add a variant, change the theme or the catalog; do not pass raw styles in props.

## c. Style hooks

Each standard component has a style protocol shaped like `ButtonStyle`: `JRCardStyle`, `JRTableStyle`, `JRTabsStyle`, `JRLinkStyle`, `JRInputStyle` and so on (one per component that draws its own chrome), set with a `.jr<Name>Style(_:)` modifier. Charts share one protocol, `ChartStyle`, set per chart type with `.jrChartStyle(_:for:)` (for example `for: .bar`); `.jrChartMarks(for:_:)` replaces only the marks. A style receives a configuration (resolved props, label views, flags, the theme) and returns a view. It never receives the store, bindings or `emit`, so it cannot change behaviour.

```swift
import JSONRender
import SwiftUI

struct QuietCardStyle: JRCardStyle {
    func makeBody(configuration: JRCardStyleConfiguration) -> some View {
        VStack(alignment: .leading) {
            configuration.title
            configuration.content
        }
    }
}

struct QuietCards<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content.jrCardStyle(QuietCardStyle())
    }
}
```

## d. Slots

Slots are named child regions: `header`, `footer`, `leading`, `trailing`, `empty`, `loading`, `error`; charts add `title`, `caption`, `tooltip`, `center`. A spec fills them with `slots`. A component renders a slot with `context.slots["footer"]`, a `JRChildren` that is a `View`.

## e. Replace a component's view

The catalog keeps the definition (props, prompt text, validation); you replace the view:

```swift
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI

struct PlainTable: View {
    let context: JRRenderContext

    var body: some View {
        Text(context.prop("caption")?.stringValue ?? "")
    }
}

func catalogWithPlainTable() throws -> Catalog {
    var catalog = try Catalog.standard
    try catalog.override("Table") { context in AnyView(PlainTable(context: context)) }
    return catalog
}
```

`override` throws `unknownComponent` for a name the catalog does not define. The replacement keeps handling the same events with `context.emit` and writes bound values through the binding writer, so semantics stay the same.

## f. Custom components, actions, functions, directives, rules

A custom component is a SwiftUI view with the `@JRComponent` macro (product `JSONRenderClient`). The macro writes the catalog definition from the `@JRProp` properties and an `init(context:)`:

```swift
import JSONRenderClient
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import SwiftUI

@JRComponent("Metric", description: "A KPI with a label and a value.", events: ["press"])
struct Metric: View {
    @JRProp(description: "Short label") var label: String
    @JRProp(description: "The formatted value") var value: String
    @JRProp(description: "Direction of change", oneOf: ["up", "down", "flat"]) var trend: String?

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
            Text(value)
        }
    }
}

func catalogWithMetric() throws -> Catalog {
    var catalog = try Catalog.standard
    try catalog.register(Metric.self)
    return catalog
}
```

Supported prop types: `String`, `Double`, `Float`, `CGFloat`, `Int`, `Bool`, `JSONValue`, arrays and optionals of those. A default value makes a prop optional; `T?` is nullable; use `[JSONValue]` for lists of objects and decode them in the view. `secret: true` lists a prop in `secretProps`. `bindable: true` documents that the prop takes `$bindState`. Register a name once; a duplicate throws `duplicateComponent`.

Functions, directives and rules:

```swift
import JSONRenderCore
import JSONRenderStandardCatalog

func extendedCatalog() throws -> Catalog {
    var catalog = try Catalog.standard

    // $computed: { "$computed": "fullName", "args": { "first": ..., "last": ... } }
    catalog.function("fullName", description: "Join a first and a last name") { args in
        let first = (args["first"] ?? nil)?.stringValue ?? ""
        let last = (args["last"] ?? nil)?.stringValue ?? ""
        return .string("\(first) \(last)")
    }

    // A directive: { "$double": { "$state": "/count" } }
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

    // A rule that adds issues to Catalog.validate
    catalog.rule("no-empty-card") { spec, _ in
        spec.elements.keys.sorted().compactMap { id in
            guard spec.elements[id]?.type == "Card", spec.elements[id]?.children?.isEmpty == true
            else { return nil }
            return SpecIssue(
                severity: .warning, code: .customRule, message: "Card \(id) is empty.",
                elementKey: id)
        }
    }
    return catalog
}
```

- A directive name starts with `$` and must not be a built-in key (`$state`, `$item`, `$index`, `$bindState`, `$bindItem`, `$cond`, `$computed`, `$template`). It resolves sub-values with `resolver.resolveValue(_:)` so it composes with other expressions.
- Function and directive descriptions appear in `Catalog.prompt()`; write them for a model.
- Iterate a dictionary in sorted key order when you build output or ids.
- Catalogs merge with `merging(_:)`; a name in both throws a `duplicate...` error.
- Host actions: see `actions.md`.
