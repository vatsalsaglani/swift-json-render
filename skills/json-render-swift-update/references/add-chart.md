# Add or change a chart

Contents: the contract, data decoding, the file, style protocol and mark override, accessibility and table, limits and rules, skeleton and streaming, registration, tests, end of the chain.

`JSONRenderCharts` is an optional product on Swift Charts and SwiftUI `Gauge`. One component per chart with focused props. There is no "Chart" with a `kind` switch. A chart never has children.

## 1. The contract

- Add the chart to the VPLAN 7.3 table and to `skills/json-render-swift-use/references/charts.md` (the hand-written variants and limits; the prop list is generated). A chart that does not fit one of the "choosing" rows needs a reason.
- Props: the shared props (`data`, `x`, `y`, `series`, `label`, `value`, `format`, `unit`, `xDomain`, `yDomain`, `referenceLines`, `legend`, `height`, `emptyText`, `selection`, `summary`, `variant`, `title`, `caption`) plus only the few props that chart needs. Enum values are lowercase words.
- Default look: one hue, bars from zero, horizontal hairline grid with 3 to 5 ticks, tabular compact numbers, no 3D, no gradient, no dual axis, no decoration. Status colour only for a status, and always with a sign, a label or a shape.
- Pick the limits now: points, series, groups or cells, and what happens over them (fold into "Other", downsample, or a validator error).

## 2. Decode data once

`ChartData.make(props:kind:) -> (ChartData, [ChartWarning])` is a pure function in `Support/ChartData+Make.swift`. It extracts rows by field name, parses ISO-8601 dates once (a time axis), skips rows with a missing `x` or non-numeric `y` (counts them), keeps series in first-appearance order, sorts out-of-order time points, and computes nice domains. A chart with its own shape has its own `make(props:)` in its component file (`Funnel`, `Treemap`, `Waterfall`, `BoxPlot`, `Candlestick`; `Gauge` uses `GaugeModel.make(props:)`). Unit-test it without views. Never parse, sort or aggregate in `body`: `ChartContainer` memoises the result per data change.

`ChartData` is a `Sendable` struct. `ChartWarning` is the single source of every chart message; a case that `isBlocking` shows its `message` instead of marks (`tooManyPoints`, `tooManySeries`, `tooManySlices`, `negativeSlice`, `tooManyCells`, `tooManyGroups`, `stageIncrease`). `ChartContainer` (`Support/ChartFrame.swift`) draws the shared chrome: title, caption, legend, empty text, skeleton, "Show as Table", selection, the streaming domain and the accessibility summary.

## 3. The file

`Sources/JSONRenderCharts/Components/<Name>.swift`:

```swift
// not compiled: the names inside JSONRenderCharts (ChartProps, ChartKind, ChartContainer) are internal to the module
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

public struct Funnel: View, JRComponentType {
    nonisolated public static let definition = ComponentDefinition(
        name: ChartKind.funnel.rawValue,
        description: "Stages that narrow. Each stage must not be larger than the one before it unless sort is set.",
        props: .object(
            [
                ChartProps.data,
                ChartProps.field("label", "Field for the stage name."),
                ChartProps.field("value", "Field for the stage value."),
                ChartProps.choice("show", ["value", "percent", "both"], "What each bar shows."),
            ] + ChartProps.chrome(domains: false)),
        slots: ChartProps.slots)

    let context: JRRenderContext

    public init(context: JRRenderContext) { self.context = context }

    public var body: some View {
        ChartContainer(kind: .funnel, context: context, make: FunnelData.make, fixedHeight: false) {
            input in FunnelPlot(input: input)
        }
    }
}
```

A chart is a hand-written `ComponentDefinition` plus `JRComponentType`, not `@JRComponent`: the shared props (`ChartProps.chrome`) and the slots (`ChartProps.slots`) come from one place, so every chart prints the same chrome props. Add a case to `ChartKind` (its raw value is the component name).

- Swift Charts marks (`BarMark`, `LineMark`, `AreaMark`, `SectorMark`, `PointMark`, `RectangleMark`, `RuleMark`) cover most charts. Treemap and other shapes Swift Charts cannot draw use `Canvas` with a pure layout function (`TreemapLayout.squarify(values:in:gap:)`), tested by property tests.
- Chart colour comes from `theme.charts` (`categorical`, `sequential`, `diverging`, `gridline`, `axisFont`, `barCornerRadius`, `lineWidth`, `pointSize`, `gaugeTrackWidth`, `sliceGap`). Do not add a field: the token struct is frozen (`theme-tokens.md`).
- Value axes go through `.jrValueAxes(input, horizontal:aligned:)` (`aligned: true` for charts whose marks sit between ticks, such as Waterfall and BoxPlot). The pointer axis (`ChartPointerAxis`) is `.x` by default, `.y` for horizontal bars, `.angle` for pie slices and `.index` for a numeric index into the categories (Candlestick periods).
- Do not import `JSONRenderStandardCatalog`. "Show as Table" uses a plain SwiftUI `Table` inside the charts module.

## 4. Style protocol and mark override

One protocol serves every chart: `ChartStyle` with `makeBody(configuration: ChartStyleConfiguration)`. The configuration holds `kind: ChartKind`, `data: ChartData`, `yDomain`, `selection: Binding<String?>`, `tokens: ChartTokens`, `marks: AnyView` (the default plot) and `isStreaming`. One environment value (`jrChartStyles`, a `ChartStyleSet`) holds a style per `ChartKind`, set with `.jrChartStyle(_:for: .bar)` or `.jrChartStyle(_:for: [.bar, .line])`. A host replaces only the marks with `.jrChartMarks(for: .bar) { data in ... }` (a `@ChartContentBuilder` over `ChartData`); data handling, descriptor, selection and chrome stay in the component. A new chart needs a `ChartKind` case, not a new protocol.

## 5. Accessibility, selection, table

- Set `accessibilityChartDescriptor` (AXChartDescriptor) on every chart. Treemap and Funnel use a categorical x axis of labels and a numeric y axis of values.
- Label each mark with the format applied: "Run 4210, 70 seconds".
- `summary` defaults to `ChartSummary.text(for:)`, for example "Bar chart, 7 runs, highest 70 s at run 4210". Test it.
- Selection: use `.jrPointerSelection(input, axis:)` (a `chartOverlay` with hover and tap), not `chartXSelection`: on macOS the system selection follows hover and returns to nil when the pointer leaves, so writing it to state would make a drill-down flicker. Hover moves a local highlight only; a click (or a key) commits the label under the pointer through `input.commit`, and a second click deselects. The container writes the label to the pointer in `context.bindings["selection"]` through the environment's `jrWriteBinding`. A donut hole selects nothing. Arrow keys move the selection when the chart has focus.
- "Show as Table": a context menu item and a visible button path. Same rows.
- Increase Contrast and colour-vision safety: the categorical palette passes 3:1 against the card and a minimum neighbour distance; high-contrast adds a dash pattern after the fourth series. Do not claim more than you test.

## 6. Limits and rules

- Budgets live in `Support/ChartBudgets.swift`: points 5,000 (error), Line and Area over 1,000 downsampled by LTTB (a pure, tested function: endpoints kept, exact count, monotone x), series 12 (error), over 8 a dash cycle, pie 6 shown and 12 accepted, heatmap cells 2,500, waterfall 12 steps, funnel 8 stages, boxplot 20 groups, candlestick 180 periods, treemap 200 cells.
- Add the chart's rules to `Support/ChartSpecRules.swift` (mark charts) or `CompositeChartRules` in `ChartEntries+Composite.swift` (composite charts); they are registered on the chart catalog with `Catalog.rule(_:_:)` (`SpecRule = (Spec, JSONValue?) -> [SpecIssue]`). Each issue is `SpecIssue(severity:, code: .customRule, message: "<Type> <id>: <rule text>", elementKey: id)`; the message names the element and the rule, never data values. Test every rule with a positive and a negative spec.
- `$computed` aggregations (`groupSum`, `countBy`, `topN`, `bucket`) are registered on `Catalog.charts` with `Catalog.function(_:description:_:)`. Args are `[String: JSONValue?]`; a missing or wrong-typed arg gives `nil`. Output order is deterministic: sorted keys, or first-appearance when asked. Never iterate a dictionary unsorted when you build output.

## 7. Skeleton and streaming

- Before `data` arrives, draw a skeleton (axes and three ghost bars) from the theme. No spinner.
- While `jrStreamPhase == .streaming` the y-domain only grows (`MonotonicDomain`: round up to a 1-2-5 number, never shrink) and settles once on `.final` (animated; none under Reduce Motion). Series keep first-appearance order.
- Redraw is at most once per frame; the frame coalescer does that. Keep `body` cheap.

## 8. Register

In `ChartEntries+Marks.swift` (mark charts) or `ChartEntries+Composite.swift` (composite charts): add `Funnel.definition` to the `marks` or `composite` list and `try catalog.register(Funnel.self)` to `registerMarks` or `registerComposite`, in the order of the VPLAN 7.3 table. `Catalog.charts` merges with the standard catalog through `merging(_:)`; a duplicate name throws.

## 9. Tests

- `ChartDataTests` and `ChartKindDataTests`: field extraction, ISO dates, skipped rows, series order, nice domains, bars from zero.
- `FormatTests`: compact 1.2k, 3.4 MB, 41 s, 72 %, $3.60.
- Pure maths for the chart (waterfall running totals, funnel percent between steps, box plot quartiles including n < 4 and all-equal, treemap tiling and no overlap with seeded random inputs; print the seed on failure).
- `ChartDefinitionTests`: name, formatted props, description.
- `ChartSpecRulesTests` (and `Composite/` for the composite rules), `ChartDescriptorTests`, `ChartSummaryTests`, `SelectionTests` (writes through `jrWriteBinding`), `DomainTests`, `LTTBTests`, `ChartStyleTests`.
- `ChartSnapshotSmokeTests`: renders the chart offscreen in both token roles (a crash test, not a pixel test).
- A fixture spec in `Tests/ParityFixtures/charts/` (your own sibling folder) with the `index.json` row.

## End of the chain

Gallery page under `Examples/Gallery/Sources/Gallery/Charts/` (every variant, in a Card) and its line in `GalleryPages.all`; regenerate `skills/json-render-swift-use/references/charts.md` with `skills/scripts/refresh-catalog-reference.sh` and update the hand-written parts of that file; refresh the site data (`release.md`); add a CHANGELOG line.
