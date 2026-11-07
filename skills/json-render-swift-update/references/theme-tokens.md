# Theme tokens and presets

Contents: the frozen token struct, presets, validated(), per-type override, chart tokens and the dependency direction.

## The token struct is frozen

`JSONRenderTheme` is `{ color, type, space, radius, elevation, motion, charts }` in `Sources/JSONRenderSwiftUI/Theme/Tokens.swift`. Its shape is frozen: a new field, a renamed field or a new token struct is a **coordinator change**, because every preset, style and chart reads it. Stop and report; do not add a field to make a component easier. Add a value to a preset, or compute a derived value inside the component from existing tokens.

| Group | Fields |
|---|---|
| `ColorRoles` | surface, surfaceRaised, text, textSecondary, textMuted, hairline, accent, onAccent, good, warning, critical, info, focus |
| `TypeScale` | caption, footnote, body, bodyEmphasis, title, display, mono, weights |
| `SpaceScale` | s1 to s6 |
| `RadiusScale` | control, field, card |
| `Elevation` | cardShadowRadius, cardShadowY, cardShadowOpacity |
| `Motion` | reveal, pulse (zero under Reduce Motion) |
| `ChartTokens` | categorical (8), sequential, diverging, gridline, axisFont, barCornerRadius, lineWidth, pointSize, gaugeTrackWidth, sliceGap |

The environment value is `EnvironmentValues.jsonRenderTheme` (default `.native`).

## Presets

Presets live in `Sources/JSONRenderSwiftUI/Theme/Presets/`. `.native` follows the system (light and dark, Increase Contrast, Dynamic Type). `.highContrast` has a 2 pt opaque hairline and `textMuted` equal to `textSecondary`. <!-- verify after jr-3 merges: .highContrast and the final .native values -->

Default look rules the values must keep:

- Accent only on the primary Button, the active Tab, the Switch when on, Progress and the focus ring. Status colours always come with an icon and a word.
- One radius scale (control, field, card); no shadow inside a card; the elevated Card variant has one shadow.
- Space 4 / 8 / 12 / 16 / 20 / 32; type 11 / 12 / 13 / 15 / 20 / 28 pt; tabular digits in data.
- Motion: 180 ms reveal, none under Reduce Motion.

Rafu's own presets (`.rafuIndigo`, `.rafuKhadi`) are not in this package; the Rafu app maps its palette to a `JSONRenderTheme`.

## validated()

`JSONRenderTheme.validated()` checks contrast at load and throws `ThemeContrastError` listing the failing pairs. The planned rules: text and textSecondary on surface at least 4.5:1, textMuted at least 3:1 (or raise it to 4.5:1), accent on surface at least 3:1, onAccent on accent at least 4.5:1. Colours resolve to sRGB in both appearances. A debug build asserts; a release build logs once per theme, with role names only. <!-- verify after jr-3 merges: the final thresholds and the muted-text decision -->

Every preset must pass `validated()` in a test, and a test with a broken theme must throw with the failing pair names.

## Overrides

- <!-- verify after jr-3 merges: the three modifiers and ElementView --> Whole theme: `.jsonRenderTheme(_:)`. One token: `.jsonRenderTheme(\.radius.card, 6)`. Per component type: `.jsonRenderTheme(_:forTypes:)`, stored in a type-to-theme environment map that `ElementView` applies to the subtree.
- Precedence: per-type beats per-token beats whole. <!-- verify after jr-3 merges -->
- A component reads `@Environment(\.jsonRenderTheme)`. It never reads a global.

## Chart tokens and the dependency direction

`JSONRenderSwiftUI` cannot import `JSONRenderCharts` (the graph is one way), so the SwiftUI presets can never see values defined in the charts target. On main, `JSONRenderTheme.native` carries `ChartTokens.standard` (an Okabe-Ito categorical palette, a blue sequential ramp, an orange-to-blue diverging ramp) defined in `Theme/Presets/ChartTokens+Defaults.swift`. The charts target may define tuned `ChartTokens.native` and `.highContrast` values; if so, the host sets `.jsonRenderTheme(\.charts, .native)`. Moving the colours into the SwiftUI target is a boundary change for the coordinator. Do not add a reverse dependency. <!-- verify after jr-3c merges -->

Chart palette checks: each categorical colour at least 3:1 against the card surface, and a minimum distance between neighbours. State the method you used (for example CIE76 on a simulated colour-vision-deficiency copy) and do not claim more than you test.
