# Changelog

All notable changes to swift-json-render are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

Versioning: the package tracks upstream json-render by minor, so `0.22.x` follows upstream 0.22. Pre-release tags are `0.22.0-alpha.N`. A patch fixes bugs and text without moving a prompt fixture line. A minor adds components, props, charts, directives or rules and removes nothing. Removing or renaming an upstream name, a prop, a param or an expression changes semantics and is not allowed inside a minor. Each release names the upstream commit it implements.

## [Unreleased]

### Added

- GitHub Actions workflow with a format check, a macOS build and test (parallel and serial), a Linux build and test of the platform-neutral targets, and a DocC build. The serial macOS job also builds the Gallery and its snapshots, checks the skills and the showcase site, and checks the network boundary in the compiled objects.
- DocC catalog with ten articles: getting started, the spec, expressions, streaming, nesting, theming, charts, parity, security and compose.
- `docs/parity.md`, generated from the parity suites by `Scripts/parity-report.sh` (case counts per fixture folder, the pinned upstream commit, what is not upstream).
- `README.md` with a quick start, `CONTRIBUTING.md`, and a dated third-party list in `NOTICE`.
- `skills/scripts/compile-examples.sh`: builds every Swift block of both skills, the README and the DocC articles against the checkout.
- Showcase site: `site/tools/dump-catalog.sh` and `site/tools/merge-catalog.mjs` regenerate the component pages from the Swift catalogs, and the pages show Gallery screenshots.

### Changed

- The skills are refreshed against the real catalogs: the generated component and chart lists show all 36 and 15 components, and every "verify after" marker is resolved against the code (names, slots, theme rules, link policy, table repeat form, chart style API and file layout).
- Showcase site: the 36 standard and 15 chart pages now take description, props, events and slots from the Swift catalogs. Example specs that used props the package does not have (for example `Card.subtitle`, `Alert.text`, `Pagination.total`) now use the real props, and all 61 of them pass `Catalog.validate`.

## [0.22.0-alpha.2] - 2026-11-08

Implements json-render 0.22.0 (`1819412`).

### Added

- `JSONRender`, an umbrella product: one `import JSONRender` brings the core, the SwiftUI renderer and the standard catalog (it re-exports those three). Charts, the composer and remote images stay separate imports.
- `JSONRenderCompose`: an optional batched composer on the OpenAI Decisions API. The app supplies candidates; the evaluator picks, places and orders them in at most two requests, and never sees props, bindings or state. Fallbacks are visible in each step. The base URL must be `https` (`DecisionError.insecureBaseURL`), the key comes from a closure and is never stored or logged, and a candidate error is a `CompositionError`.
- `StreamModel.run(_:mode:onFinish:)` for any sendable `AsyncSequence` of text, and `StreamModel.run(bytes:mode:onFinish:)` for UTF-8 chunks.
- `JSONRenderStreamView` initialisers that draw each snapshot with `JSONRenderView` by default (`stream:mode:catalog:host:limits:observer:onFinish:` and `model:catalog:host:observer:`).
- `RenderWalk.watchSites`, `JRTableStyleConfiguration.totalRows`, `ChartWarning.tooManyGroups` and `.stageIncrease`, `ChartPointerAxis.index`, and `jrValueAxes(aligned:)`.
- The DocC plugin as a package dependency for documentation builds only.

### Changed

- A mixed stream reports a JSON line with an unknown `op` or no `path` as a bad patch line instead of treating it as prose.
- Object mode fails fast on JSON that no continuation can make valid, instead of waiting for the end of the stream.
- Running a `StreamModel` again resets its state store as well as its spec.
- `watch` bindings run on hidden elements and on elements of an unknown type, as upstream does.
- A Table draws at most 500 literal rows and says "Showing 500 of N rows".
- A donut hole does not select a slice, and Waterfall connectors stay between the bars.
- The skeleton fill is visible in light appearance, and an elevated card in dark appearance has a lighter top hairline.
- `FrameCoalescer.offer` and `tick` are internal.

## [0.22.0-alpha.1] - 2026-11-08

Implements json-render 0.22.0 (`1819412`).

### Added

- The SwiftUI renderer: `JSONRenderView`, per-element resolution, repeat rows, slots, watchers, fallback blocks, and the accessibility audit.
- Themes: `JSONRenderTheme` with `.native` and `.highContrast`, contrast validation, per-token and per-type overrides, and chart tokens.
- 36 standard components with upstream names and props, a style protocol per component, the four standard directives (`$format`, `$count`, `$join`, `$pluralize`), form validation wiring, and the remote image hook (`JRRemoteImageProvider`).
- 15 charts on Swift Charts: BarChart, LineChart, AreaChart, PieChart, Gauge, Sparkline, ScatterChart, Heatmap, Histogram, ComboChart, Waterfall, Funnel, BoxPlot, Candlestick and Treemap, with budgets, VoiceOver summaries and a "Show as Table" view.
- Streaming: `SpecStreamDecoder` (JSONL, mixed and object modes), `SpecStore`, `StreamModel` (one publish per display frame) and `JSONRenderStreamView`.
- The Gallery app with a page for every component and chart, and a headless snapshot mode.
- Two skills: `json-render-swift-use` and `json-render-swift-update`.

### Changed

- A pattern check that cannot be run safely reports a neutral message instead of the spec's own text.

## [0.22.0-alpha.0] - 2026-11-07

Implements json-render 0.22.0 (`1819412`).

### Added

- `JSONRenderCore`: the JSON value and pointer types, the spec model and decoder, expressions, visibility, the state store, actions and the dispatcher, the validator and auto-fix, the catalog, prompt and JSON Schema, `Spec.composing`, and the nested-to-flat conversion.
- `JSONRenderClient`: the `@JRComponent` and `@JRProp` macros.
- Parity fixtures from upstream at the pinned commit, with an offline checker.
- The showcase site and the plan.
