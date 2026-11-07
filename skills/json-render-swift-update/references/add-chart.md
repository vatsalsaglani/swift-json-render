# Add or change a chart

Contents: the contract, data decoding, the file, style protocol and mark override, accessibility and table, limits and rules, skeleton and streaming, registration, tests, end of the chain.

<!-- verify after jr-3c and jr-3d merge: every file and type name below comes from the jr-3c brief. Check against Sources/JSONRenderCharts. On main: the ChartEntries seeds, ChartTokens (in JSONRenderSwiftUI), the Catalog rule hook and the $computed function hook -->

`JSONRenderCharts` is an optional product on Swift Charts and SwiftUI `Gauge`. One component per chart with focused props. There is no "Chart" with a `kind` switch. A chart never has children.

## 1. The contract

- Add the chart to the VPLAN 7.3 table and to `skills/json-render-swift-use/references/charts.md` (variants, props, limits). A chart that does not fit one of the "choosing" rows needs a reason.
- Props: the shared props (`data`, `x`, `y`, `series`, `label`, `value`, `format`, `unit`, `xDomain`, `yDomain`, `referenceLines`, `legend`, `height`, `emptyText`, `selection`, `summary`, `variant`, `title`, `caption`) plus only the few props that chart needs. Enum values are lowercase words.
- Default look: one hue, bars from zero, horizontal hairline grid with 3 to 5 ticks, tabular compact numbers, no 3D, no gradient, no dual axis, no decoration. Status colour only for a status, and always with a sign, a label or a shape.
- Pick the limits now: points, series, groups or cells, and what happens over them (fold into "Other", downsample, or a validator error).

## 2. Decode data once

`ChartData.make(props:) -> (ChartData, [ChartWarning])` is a pure function in `Support/ChartData.swift`. It extracts rows by field name, parses ISO-8601 dates once (a time axis), skips rows with a missing `x` or non-numeric `y` (counts them), keeps series in first-appearance order, sorts out-of-order time points, and computes nice domains. Unit-test it without views. Never parse, sort or aggregate in `body`; memoise by the hash of `props["data"]` in a small `@State` cache.

`ChartData` is a `Sendable` struct. `ChartFrame` draws the shared chrome: title, caption, legend, empty text, skeleton.

## 3. The file

`Sources/JSONRenderCharts/Components/<Name>.swift`:

```swift
// verify after jr-3c merges
@JRComponent("Funnel", description: "Stages that shrink, widest first. At most 8 stages.")
struct Funnel: View {
    @JRProp var data: JSONValue
    @JRProp var label: String
    @JRProp var value: String
    @JRProp(oneOf: ["value", "percent", "both"]) var show: String = "both"
    // shared props ...
    var body: some View { ChartFrame(...) { /* marks */ } }
}
```

- Swift Charts marks (`BarMark`, `LineMark`, `AreaMark`, `SectorMark`, `PointMark`, `RectangleMark`, `RuleMark`) cover most charts. Treemap and other shapes Swift Charts cannot draw use `Canvas` with a pure layout function (`TreemapLayout.squarify(values:in:gap:)`), tested by property tests.
- Chart colour comes from `theme.charts` (`categorical`, `sequential`, `diverging`, `gridline`, `axisFont`, `barCornerRadius`, `lineWidth`, `pointSize`, `gaugeTrackWidth`, `sliceGap`). Do not add a field: the token struct is frozen (`theme-tokens.md`).
- Do not import `JSONRenderStandardCatalog`. "Show as Table" uses a plain SwiftUI `Table` inside the charts module.

## 4. Style protocol and mark override

Each chart has a style protocol (`BarChartStyle` pattern): `makeBody(configuration:)` with a configuration holding `data: ChartData`, scales, `selection: Binding<JSONValue?>`, `tokens: ChartTokens`, `marks: AnyView` (the default marks) and `isStreaming`. One environment value holds an optional style per chart type (`.jrChartStyle(_:)`). A host replaces only the marks with `.jrChartMarks(for: "BarChart") { data in ... }` (a `@ChartContentBuilder`); data handling, descriptor, selection and chrome stay in the component.

## 5. Accessibility, selection, table

- Set `accessibilityChartDescriptor` (AXChartDescriptor) on every chart. Treemap and Funnel use a categorical x axis of labels and a numeric y axis of values.
- Label each mark with the format applied: "Run 4210, 70 seconds".
- `summary` defaults to `ChartSummary.text(for:)`, for example "Bar chart, 7 runs, highest 70 s at run 4210". Test it.
- Selection: `chartXSelection(value:)` or `chartAngleSelection(value:)` on a local `@State`; on change, write the selected x value or slice label to the pointer in `context.bindings["selection"]` through the environment's `jrWriteBinding`. Arrow keys move the selection when the chart has focus.
- "Show as Table": a context menu item and a visible button path. Same rows.
- Increase Contrast and colour-vision safety: the categorical palette passes 3:1 against the card and a minimum neighbour distance; high-contrast adds a dash pattern after the fourth series. Do not claim more than you test.

## 6. Limits and rules

- Budgets live in `Support/ChartBudgets.swift`: points 5,000 (error), Line and Area over 1,000 downsampled by LTTB (a pure, tested function: endpoints kept, exact count, monotone x), series 12 (error), over 8 a dash cycle, pie 6 shown and 12 accepted, heatmap cells 2,500, waterfall 12 steps, funnel 8 stages, boxplot 20 groups, candlestick 180 periods, treemap 200 cells.
- Add the chart's rules to `Support/ChartSpecRules.swift` and register them on the chart catalog with `Catalog.rule(_:_:)` (`SpecRule = (Spec, JSONValue?) -> [SpecIssue]`). Each issue is `SpecIssue(severity:, code: .invalidProps or .customRule, message: "<Type> <id>: <rule text>", elementKey: id)`; the message names the element and the rule, never data values. Test every rule with a positive and a negative spec.
- `$computed` aggregations (`groupSum`, `countBy`, `topN`, `bucket`) are registered on `Catalog.charts` with `Catalog.function(_:description:_:)`. Args are `[String: JSONValue?]`; a missing or wrong-typed arg gives `nil`. Output order is deterministic: sorted keys, or first-appearance when asked. Never iterate a dictionary unsorted when you build output.

## 7. Skeleton and streaming

- Before `data` arrives, draw a skeleton (axes and three ghost bars) from the theme. No spinner.
- While `jrStreamPhase == .streaming` the y-domain only grows (`MonotonicDomain`: round up to a 1-2-5 number, never shrink) and settles once on `.final` (animated; none under Reduce Motion). Series keep first-appearance order.
- Redraw is at most once per frame; the frame coalescer does that. Keep `body` cheap.

## 8. Register

In `ChartEntries+Marks.swift` (jr-3c's group) or `ChartEntries+Composite.swift` (jr-3d's group): add the definition to the list and `try catalog.register(Funnel.self)` to the register function, in the order of the VPLAN 7.3 table. `Catalog.charts` merges with the standard catalog through `merging(_:)`; a duplicate name throws.

## 9. Tests

- `ChartDataTests`: field extraction, ISO dates, skipped rows, series order, nice domains, bars from zero.
- Format tests: compact 1.2k, 3.4 MB, 41 s, 72 %, $3.60.
- Pure maths for the chart (waterfall running totals, funnel percent between steps, box plot quartiles including n < 4 and all-equal, treemap tiling and no overlap with seeded random inputs; print the seed on failure).
- `ChartDefinitionTests`: name, formatted props, description.
- Rule tests, descriptor and summary tests, selection writes through `jrWriteBinding`.
- A smoke test that renders the chart offscreen in both token roles (a crash test, not a pixel test).
- A fixture spec in `Tests/ParityFixtures/charts/` (your own sibling folder) with the `index.json` row.

## End of the chain

Gallery page under `Examples/Gallery/Charts/` (every variant, in a Card); regenerate `skills/json-render-swift-use/references/charts.md` with `skills/scripts/refresh-catalog-reference.sh` and update the hand-written parts of that file; hand the coordinator the `GalleryPages.all` line and a CHANGELOG line.
