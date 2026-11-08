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

Presets live in `Sources/JSONRenderSwiftUI/Theme/Presets/` (`Native.swift`, `HighContrast.swift`, `ChartTokens+Defaults.swift`). `.native` follows the system (light and dark, Increase Contrast; Dynamic Type on iOS, a fixed 11 / 12 / 13 / 15 / 20 pt ramp on macOS). `.highContrast` has an opaque hairline that draws at 2 pt, `text` at full ink, and `textMuted` equal to `textSecondary`; `onAccent` is black or white, whichever has more contrast with the accent. Under the system Increase Contrast setting, any theme steps `textMuted` up to `textSecondary` (`adjusted(for:)`).

Default look rules the values must keep:

- Accent only on the primary Button, the active Tab, the Switch when on, Progress and the focus ring. Status colours always come with an icon and a word.
- One radius scale (control, field, card); no shadow inside a card; the elevated Card variant has one shadow.
- Space 4 / 8 / 12 / 16 / 20 / 32; type 11 / 12 / 13 / 15 / 20 / 28 pt; tabular digits in data.
- Motion: 180 ms reveal, none under Reduce Motion.

Rafu's own presets (`.rafuIndigo`, `.rafuKhadi`) are not in this package; the Rafu app maps its palette to a `JSONRenderTheme`.

## validated()

`JSONRenderTheme.validated()` throws `ThemeContrastError` listing the failing pairs. The rules are `JSONRenderTheme.contrastRules`: text and textSecondary on surface and on surfaceRaised at least 4.5:1, textMuted on surface at least 3:1 (it is only for hints next to a real label), accent on surface at least 3:1, onAccent on accent at least 3:1 (the macOS system accent with white text measures about 4.0:1, so 4.5:1 would reject the system look). `contrastReport()` returns every measured pair. Colours resolve to sRGB in both appearances; a translucent foreground is composited over its background first. `JSONRenderView` audits each theme once per process when it appears: a debug build asserts (not under tests), a release build logs once with role names and ratios only.

Every preset must pass `validated()` in a test, and a test with a broken theme must throw with the failing pair names.

## Overrides

- Whole theme: `.jsonRenderTheme(_:)`. One token: `.jsonRenderTheme(\.radius.card, 6)` (stored in `\.jsonRenderThemeTokens`, so its order against the whole-theme modifier does not matter). Per component type: `.jsonRenderTheme(_:forTypes:)` takes a `Set<String>` and is stored in `\.jsonRenderTypeThemes`; `ResolvedElementView` computes the effective theme per element (`JSONRenderTheme.effective(forType:typeThemes:tokens:contrast:)`).
- Precedence: per-type beats per-token beats whole.
- A component reads `@Environment(\.jsonRenderTheme)`. It never reads a global.

## Chart tokens and the dependency direction

`JSONRenderSwiftUI` cannot import `JSONRenderCharts` (the graph is one way), so the SwiftUI presets can never see values defined in the charts target. On main, `JSONRenderTheme.native` carries `ChartTokens.standard` (an Okabe-Ito categorical palette, a blue sequential ramp, an orange-to-blue diverging ramp) defined in `Theme/Presets/ChartTokens+Defaults.swift`. `ChartTokens.defaults(role:)` gives `.standard` for `.native` and `.standard` with an opaque gridline and a heavier line for `.highContrast`. The charts target defines no tokens of its own, so there is no `ChartTokens.native`; a host changes one chart token with `.jsonRenderTheme(\.charts.lineWidth, 1.5)`. Do not add a reverse dependency.

Chart palette checks: each categorical colour at least 3:1 against the card surface, and a minimum distance between neighbours. State the method you used (for example CIE76 on a simulated colour-vision-deficiency copy) and do not claim more than you test.
