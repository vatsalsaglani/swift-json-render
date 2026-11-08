# Charts

Fifteen chart components on Swift Charts, in the optional `JSONRenderCharts` product.

## Use them

Each chart is its own component type with a few props. There is no `Chart` with a `kind` switch, and a chart has no children. Merge the chart catalog with the standard one:

```swift
import JSONRender
import JSONRenderCharts

func catalogWithCharts() throws -> Catalog {
    try Catalog.standard.merging(Catalog.charts)
}
```

`BarChart`, `LineChart`, `AreaChart`, `PieChart`, `Gauge`, `Sparkline`, `ScatterChart`, `Heatmap`, `Histogram`, `ComboChart`, `Waterfall`, `Funnel`, `BoxPlot`, `Candlestick` and `Treemap`.

```json
{ "type": "BarChart",
  "props": { "data": { "$state": "/runs" }, "x": "run", "y": "secs",
             "selection": { "$bindState": "/picked" } },
  "children": [] }
```

The shared props are `data`, `x`, `y`, `series`, `label`, `value`, `format`, `unit`, `xDomain`, `yDomain`, `referenceLines`, `legend`, `height`, `emptyText`, `selection`, `summary`, `variant`, `title` and `caption`. Each chart adds only the few it needs; the generated list in the `json-render-swift-use` skill has every prop of every chart.

## Simple by default

- One series is one hue (the accent). Categorical colours appear only when `series` is set.
- Bars start at zero. Gridlines are horizontal hairlines with three to five ticks. Numbers use tabular digits.
- A status colour is never the only signal: a sign, a label or a hollow shape goes with it.
- No 3D, no gradients, no dual axes.

## Budgets

The budgets keep a chart readable and fast. They live in `ChartBudgets` and `CompositeBudgets`.

| Budget | Value | Over the limit |
|---|---|---|
| Points per chart | 5,000 | A blocking message instead of marks. Line and Area over 1,000 are downsampled (LTTB) |
| Series per chart | 12 | A blocking message. After 8 series the palette cycles with a dash pattern |
| Pie slices | 6 shown, 12 accepted | The rest go to "Other"; over 12 is an error that suggests `BarChart` |
| Heatmap cells | 2,500 | A blocking message |
| Waterfall steps, Funnel stages | 12, 8 | The rest fold into "Other" |
| BoxPlot groups | 20 | A blocking message |
| Candlestick periods, Treemap cells | 180, 200 | The last 180; the rest fold into "Other" |

Every message comes from one type, `ChartWarning`, and never contains a data value. The chart rules also run in `Catalog.validate`.

## Accessibility and tables

Every chart sets an `AXChartDescriptor` for VoiceOver audio graphs and labels each mark, for example "Run 4210, 70 seconds". `summary` is a sentence for VoiceOver; a default is built from the data when it is absent. The context menu of a chart has "Show as Table", with the same rows.

## Colours and selection

Chart colours come from `theme.charts` (eight categorical colours, sequential and diverging ramps, gridline, axis font, bar radius, line width, point size, gauge track width, slice gap). The defaults are in `JSONRenderSwiftUI`, so `JSONRenderTheme.native` already carries them. Change one token for a subtree with `.jsonRenderTheme(\.charts.lineWidth, 1.5)`.

Selection writes the clicked x value or slice label to the bound path. It never writes on hover. A donut hole selects nothing.

## Streaming

During a stream the y-domain only grows and settles once at the end. Series keep their first-appearance order, so colours do not swap. Before `data` arrives a chart shows a skeleton. A model appends points with `{"op":"add","path":"/elements/c1/props/data/-","value":{...}}`.

## Aggregation stays in the host

Specs never contain code. Four registered `$computed` functions turn state rows into chart rows: `groupSum`, `countBy`, `topN` and `bucket`.
