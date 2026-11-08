# Charts (15)

Contents: the list the model sees, variants, shared props, rules that keep charts simple, budgets, selection, nesting and streaming, aggregation, example.

Charts are an optional product: `JSONRenderCharts`. Build the catalog with `try Catalog.standard.merging(Catalog.charts)`. Each chart is its own component type with a few props; there is no "Chart" with a `kind` switch. A chart has no children. The block below is what `Catalog.prompt()` prints for the charts. It is generated; do not edit it. Regenerate with `skills/scripts/refresh-catalog-reference.sh`.

<!-- BEGIN GENERATED: charts -->
<!-- Generated from Catalog.prompt() by skills/scripts/refresh-catalog-reference.sh. Do not edit by hand. -->

```text
AVAILABLE COMPONENTS (15):

- BarChart: { data: Array<Record<string, unknown>>, x: string, y: string, series?: string, orientation?: "vertical" | "horizontal", layout?: "grouped" | "stacked" | "normalized", sort?: "none" | "asc" | "desc", limit?: number, format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Compare categories. Horizontal when labels are long; stacked or normalized (100 %) for parts of each bar. [slots: title, caption, empty, tooltip]
- LineChart: { data: Array<Record<string, unknown>>, x: string, y: string, series?: string, curve?: "linear" | "monotone" | "step", points?: "auto" | "always" | "never", xDomain?: Array<number>, format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - A trend over time. One line per series; ISO dates make a time axis. [slots: title, caption, empty, tooltip]
- AreaChart: { data: Array<Record<string, unknown>>, x: string, y: string, series?: string, layout?: "overlap" | "stacked" | "normalized", format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Totals and their parts over time. stacked: the top edge is the total; normalized: 100 % shares. [slots: title, caption, empty, tooltip]
- PieChart: { data: Array<Record<string, unknown>>, label: string, value: string, donut?: boolean, center?: string | { value: string, label?: string }, maxSlices?: number, format?: string, unit?: string, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Parts of one whole, 2 to 6 parts. Slices after maxSlices fold into Other. Negative values are rejected: use BarChart. [slots: title, caption, empty, tooltip, center]
- Gauge: { value: number, min?: number, max?: number, label?: string, target?: number, bands?: Array<{ to: number, intent: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, style?: "arc" | "ring" | "linear", format?: string, unit?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - One value against a range: a budget, coverage, CPU. The value is always printed. [slots: title, caption, center]
- Sparkline: { values: Array<number>, intent?: "good" | "warn" | "risk" | "info", emphasis?: "last" | "max" | "none", filled?: boolean, format?: string, height?: "compact" | "regular" | "tall", summary?: string, title?: string, caption?: string } - A tiny trend inside a Stat or a Table cell. No axes. [slots: title, caption]
- ScatterChart: { data: Array<Record<string, unknown>>, x: string, y: string, size?: string, series?: string, trend?: "none" | "linear", xDomain?: Array<number>, format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - The relation between two measures. size makes bubbles; trend adds a linear fit. [slots: title, caption, empty, tooltip]
- Heatmap: { data: Array<Record<string, unknown>>, x: string, y: string, value: string, scale?: "sequential" | "diverging", layout?: "grid" | "calendar", format?: string, unit?: string, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - A grid of values: activity by day and hour, failures by suite and run. calendar draws weeks by weekdays from ISO dates. [slots: title, caption, empty, tooltip]
- Histogram: { values: Array<number>, bins?: number | "auto", mode?: "count" | "percent", format?: string, unit?: string, height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - A distribution, such as test durations. bins: "auto" or a count. [slots: title, caption, empty, tooltip]
- ComboChart: { data: Array<Record<string, unknown>>, x: string, bars: string, line: string, format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Bars and a line (such as a moving average) on one y axis. Never two axes: the validator rejects a second unit. [slots: title, caption, empty, tooltip]
- Waterfall: { data: Array<Record<string, unknown>>, label: string, value: string, start?: number, subtotals?: Array<string>, orientation?: "vertical" | "horizontal", format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - How a total is built from increases and decreases: memory by subsystem, time by phase. Rows named in subtotals show the running total from the baseline. [slots: title, caption, empty, tooltip]
- Funnel: { data: Array<Record<string, unknown>>, label: string, value: string, show?: "value" | "percent" | "both", sort?: "none" | "desc", align?: "center" | "start" | "left", format?: string, unit?: string, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Stages that narrow: collected, run, passed. Each stage must not be larger than the one before it unless sort is set. [slots: title, caption, empty, tooltip]
- BoxPlot: { data: Array<Record<string, unknown>>, group: string, values?: string, orientation?: "vertical" | "horizontal", showOutliers?: boolean, format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - A distribution per group: suite durations, latency per backend. Each row has a values array, or precomputed min, q1, median, q3, max and outliers. At most 20 groups. [slots: title, caption, empty, tooltip]
- Candlestick: { data: Array<Record<string, unknown>>, x: string, open?: string, high?: string, low?: string, close?: string, mark?: "candles" | "ohlc", style?: "candles" | "ohlc", format?: string, unit?: string, yDomain?: Array<number>, referenceLines?: Array<{ value: number, label?: string, intent?: "good" | "warn" | "risk" | "info" | "warning" | "critical" }>, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Open, high, low and close per period: cost per day, build time min and max per day. Up periods are filled, down periods hollow. At most 180 periods (the last ones). [slots: title, caption, empty, tooltip]
- Treemap: { data: Array<Record<string, unknown>>, label: string, value: string, group?: string, maxDepth?: number, minLabelArea?: number, format?: string, unit?: string, legend?: "auto" | "bottom" | "trailing" | "hidden", height?: "compact" | "regular" | "tall", selection?: unknown, emptyText?: string, summary?: string, variant?: "default" | "minimal" | "dense", title?: string, caption?: string } - Parts of a whole with many parts: bundle size by module, lines by directory. Values must be greater than zero. group nests one level and colours the cells. [slots: title, caption, empty, tooltip]
```

<!-- END GENERATED: charts -->

## Variants

| Component | Renders with | Variants |
|---|---|---|
| BarChart | `BarMark` | vertical, horizontal, grouped, stacked, normalized, ranked |
| LineChart | `LineMark` (+ `PointMark`) | single, multi, stepped |
| AreaChart | `AreaMark` | area, stacked, normalized |
| PieChart | `SectorMark` | pie, donut, donut with centre |
| Gauge | SwiftUI `Gauge` + arc style | arc, ring, linear with bands and target |
| Sparkline | `LineMark` / `AreaMark`, no axes | line, filled |
| ScatterChart | `PointMark` | scatter, bubble, linear fit |
| Heatmap | `RectangleMark` | grid, calendar |
| Histogram | `BarMark` + bins | count, percent |
| ComboChart | `BarMark` + `LineMark`, one y-axis | bars + line |
| Waterfall | `RectangleMark` steps + `RuleMark` connectors | vertical, horizontal, subtotals |
| Funnel | centred horizontal bars, percent between steps | centred, left-aligned, with percent |
| BoxPlot | `RectangleMark` + `RuleMark` + `PointMark` | vertical, horizontal, outliers |
| Candlestick | `RectangleMark` body + `RuleMark` wick | candles, OHLC |
| Treemap | squarified layout on `Canvas` | flat, grouped (depth 2) |

## Shared props

Every chart accepts these. Field names (`x`, `y`, `series`, `label`, `value`) name keys of each row in `data`.

| Prop | Meaning |
|---|---|
| `data` | Array of row objects, or `{ "$state": "/runs" }` |
| `x`, `y` | Field names for the axes |
| `series` | Field that splits rows into series (adds categorical colours and a legend) |
| `label`, `value` | Field names for charts of parts (Pie, Funnel, Waterfall, Treemap) |
| `format` | `number`, `compact`, `percent`, `currency:<CODE>` (for example `currency:USD`), `duration`, `bytes` |
| `unit` | Unit text, on the axis or in the caption |
| `xDomain`, `yDomain` | `[min, max]` |
| `referenceLines` | `[{ "value", "label", "intent" }]`; give an `intent` only with a `label` |
| `legend` | `auto`, `bottom`, `trailing`, `hidden` |
| `height` | `compact` (96 pt), `regular` (160 pt), `tall` (240 pt) |
| `emptyText` | Text when `data` is empty |
| `selection` | `{ "$bindState": "/picked" }`; the chart writes the selected x value or slice label |
| `summary` | A sentence for VoiceOver. A default is generated when absent |
| `variant` | `default`, `minimal` (no axes), `dense` (smaller type, for board cards) |
| `title`, `caption` | Text; slots `title` and `caption` take elements instead |

`intent` is `good`, `warn` or `risk` (also `warning`, `critical`, `info`). Slots: `title` and `caption` on every chart; `empty` and `tooltip` on every chart except `Gauge` and `Sparkline`; `center` on `PieChart` (donut) and `Gauge` (ring).

Rows with a missing `x` or a non-numeric `y` are skipped. A field whose values are all ISO-8601 dates becomes a time axis; points that arrive out of order are sorted.

## Rules that keep charts simple

- One series is one hue (the accent). Categorical colours appear only when `series` is set. A status colour appears only for a status, such as a failure or an over-budget value.
- Bars start at zero, always. Lines may start above zero; the axis then says so.
- Gridlines are horizontal hairlines with 3 to 5 ticks. No vertical grid.
- Numbers use tabular digits and the compact format (1.2k, 3.4 MB). Put units on the axis or in the caption, not on every tick.
- Pie: at most 6 slices, then "Other". Negative values are an error and the validator suggests a BarChart. A one-slice pie shows as a single value, and a warning suggests Gauge or Stat.
- No 3D, no gradients, no dual axes, no exploded slices, no animation loops.
- Waterfall: totals and subtotals are grey from the baseline; increases take the accent, decreases the warning hue, each with a sign. At most 12 steps.
- Funnel: one hue, widest first, percent between rows. A stage larger than the one before it is a blocking error (`ChartWarning.stageIncrease`) unless `sort` is set (`desc` sorts widest first; `none` keeps the order and allows it).
- BoxPlot: at most 20 groups. Candlestick: up is good, down is critical with a hollow body; at most 180 periods. Treemap: at most 200 cells, depth at most 2; a single value becomes a Stat-like figure.
- A status colour is never the only signal; a sign, a label or a hollow shape goes with it.

## Budgets

| Limit | Value | Over the limit |
|---|---|---|
| Points per chart | 5,000 | Validator error. Line and Area over 1,000 points are downsampled (LTTB) before drawing |
| Series per chart | 12 | Validator error. After 8 series the palette cycles with a dash pattern |
| Pie slices | 6 shown, 12 accepted | Slices after 6 go to "Other". Over 12 is an error: use BarChart |
| Heatmap cells | 2,500 | Validator error |
| Waterfall steps / Funnel stages / BoxPlot groups | 12 / 8 / 20 | Steps and stages fold into "Other"; groups over 20 are an error |
| Candlestick periods / Treemap cells | 180 / 200 | Periods keep the last 180; cells fold into "Other" |
| Redraws | 1 per frame | The coalescer drops intermediate frames |

The chart rules run in `Catalog.validate` as catalog rules and give issues that name the element id and the rule, never values. Fix the spec when the validator reports one.

## Selection, accessibility, table

- `selection` writes the clicked x value (or slice label) to the bound path. Arrow keys move it when the chart has focus.
- Every chart sets an accessibility chart descriptor (VoiceOver audio graphs) and labels each mark, for example "Run 4210, 70 seconds".
- The context menu has "Show as Table", which shows the same rows in a table.

## Nesting and streaming

A chart can sit in a Card, a Tabs panel, a `repeat` (one Sparkline per row) or a Table cell. During a stream the y-domain only grows (it rounds up to a nice number) and settles once at the end. Series keep first-appearance order, so colours do not swap. Before `data` arrives the chart shows a skeleton. Append points with `{"op":"add","path":"/elements/c1/props/data/-","value":{...}}`.

## Aggregation stays in the host

Specs never contain code. Registered `$computed` functions turn state rows into chart rows: `groupSum` (rows, by, value), `countBy` (rows, by), `topN` (rows, by, value, n), `bucket` (rows, by, width or edges). Missing or wrong-typed args give undefined.

```json
"data": { "$computed": "topN", "args": { "rows": { "$state": "/runs" }, "by": "result", "value": "n", "n": 5 } }
```

## Theme

Chart colours come from `theme.charts` (`ChartTokens`: eight categorical colours, sequential and diverging ramps, gridline, axis font, bar corner radius, line width, point size, gauge track width, slice gap). `JSONRenderTheme.native` already carries a palette (`ChartTokens.standard`, eight hues spaced for colour-vision deficiencies). The defaults live in `JSONRenderSwiftUI` (`ChartTokens.standard`; `.highContrast` adds an opaque gridline and a heavier line), because the charts target depends on the SwiftUI target and not the other way round. To change one token: `theme.charts.lineWidth = 1.5`, or `.jsonRenderTheme(\.charts.lineWidth, 1.5)` for a subtree (see `install.md`).

## Example

`examples/dashboard.json` is a stat-card row, a stacked BarChart bound to `/runs` with a selection, and a Gauge with bands.
