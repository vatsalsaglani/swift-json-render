# Theming and customisation

Six layers, from least to most effort. Go down only when the layer above cannot do the job.

> Rule: customisation never changes semantics. The same spec gives the same state changes and the same emitted actions with any theme, any style and any replacement view.

| Layer | Changes | Use it for |
|---|---|---|
| a. Theme tokens | Colour roles, type, spacing, radius, elevation, motion, chart tokens | Brand and density |
| b. Variants | Looks the catalog declares and the spec picks (`variant`, `size`) | A different button or card look |
| c. Style hooks | A SwiftUI style protocol per component | A different Table or Card |
| d. Slots | Named child regions: `header`, `footer`, `empty`, `loading`, `error` | Extra content |
| e. View replacement | One component type, same props and actions | A custom Table |
| f. Custom components | New types, actions, functions, directives, rules | Domain components |

## a. Theme tokens

`JSONRenderTheme` holds `color`, `type`, `space`, `radius`, `elevation`, `motion` and `charts`. The presets are `.native` (system colours, light and dark, Increase Contrast) and `.highContrast`.

```swift
import JSONRender
import SwiftUI

func brandTheme() -> JSONRenderTheme {
    var theme = JSONRenderTheme.native
    theme.radius.card = 6
    theme.color.accent = .indigo
    return theme
}

struct Themed<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .jsonRenderTheme(brandTheme())
            .jsonRenderTheme(\.space.s3, 14)
    }
}
```

`.jsonRenderTheme(_:)` sets the whole theme, `.jsonRenderTheme(\.radius.card, 6)` one token, and `.jsonRenderTheme(_:forTypes:)` a whole theme for the listed component types. The per-type theme beats a token, and a token beats the whole theme.

`try theme.validated()` checks contrast in light and dark and throws a `ThemeContrastError` that names the failing pairs: text and secondary text 4.5:1, muted text 3:1, accent 3:1, on-accent 3:1. The renderer also audits each theme once and logs role names only.

## c. Style hooks

Each standard component with its own chrome has a style protocol shaped like `ButtonStyle`, for example `JRCardStyle`, `JRTableStyle` and `JRTabsStyle`. A style receives resolved props, label views, flags and the theme, and returns a view. It never receives the store, a binding or `emit`, so it cannot change behaviour. Charts share one protocol, `ChartStyle`, set with `.jrChartStyle(_:for:)`.

## e. Replace a view

```swift
import JSONRender
import SwiftUI

func catalogWithPlainTable() throws -> Catalog {
    var catalog = try Catalog.standard
    try catalog.override("Table") { context in
        AnyView(Text(context.prop("caption")?.stringValue ?? ""))
    }
    return catalog
}
```

The catalog keeps the definition (props, prompt text, validation); you replace the view. A replacement keeps handling events with `context.emit`.

## f. Custom components

```swift
import JSONRender
import JSONRenderClient
import SwiftUI

@JRComponent("Metric", description: "A KPI with a label and a value.")
struct Metric: View {
    @JRProp(description: "Short label") var label: String
    @JRProp(description: "The formatted value") var value: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(label)
            Text(value)
        }
    }
}
```

Register it with `try catalog.register(Metric.self)`. The macro writes the catalog definition, the prompt text and the JSON Schema entry from the `@JRProp` properties.
