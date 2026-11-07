// Owner: jr-3c (wave 2). One page per chart (VPLAN §7.3 variants), a streaming page and a
// "Show as Table" page. Each page has `static let title` and `init()`; the coordinator adds the
// `GalleryPage` conformances and the `GalleryPages.all` lines when jr-3's shell is on main.
import JSONRenderCharts
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

struct BarChartPage: View {
    static let title = "BarChart"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "Compare categories: grouped, stacked, 100 % stacked, ranked with Other, a reference line and a bound selection.",
            demos: [
        ChartDemo(
            title: "bar-grouped", type: "BarChart",
            props: [
                "data": ChartGalleryData.runs, "x": "run", "y": "n", "series": "result", "format": "compact",
                "title": "Tests by result, last 6 runs",
            ]),
        ChartDemo(
            title: "bar-stacked", type: "BarChart",
            props: [
                "data": ChartGalleryData.runs, "x": "run", "y": "n", "series": "result", "layout": "stacked",
                "format": "compact",
            ]),
        ChartDemo(
            title: "bar-normalized", type: "BarChart",
            props: ["data": ChartGalleryData.runs, "x": "run", "y": "n", "series": "result", "layout": "normalized"]),
        ChartDemo(
            title: "bar-ranked", type: "BarChart",
            props: [
                "data": ChartGalleryData.suites, "x": "suite", "y": "secs", "orientation": "horizontal",
                "sort": "desc", "limit": 4, "unit": "s", "title": "Slowest suites",
                "caption": "Seconds per suite, top 4 of 7.",
            ]),
        ChartDemo(
            title: "bar-reference", type: "BarChart",
            props: [
                "data": ChartGalleryData.suites, "x": "suite", "y": "secs", "limit": 5,
                "referenceLines": [["value": 10, "label": "Budget", "intent": "risk"]],
                ],
            bindsSelection: true),
        ChartDemo(
            title: "bar-empty", type: "BarChart", props: ["data": [], "emptyText": "No runs yet"]),
            ])
    }
}

struct LineChartPage: View {
    static let title = "LineChart"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "A trend over time: one series on a date axis, two series with a budget line, stepped.",
            demos: [
        ChartDemo(
            title: "line-single", type: "LineChart",
            props: ["data": ChartGalleryData.daily, "x": "day", "y": "secs", "unit": "s", "title": "Wall time, October"]),
        ChartDemo(
            title: "line-multi", type: "LineChart",
            props: [
                "data": ChartGalleryData.wall, "x": "run", "y": "secs", "series": "kind", "unit": "s",
                "title": "Wall time, last 12 runs",
                "referenceLines": [["value": 60, "label": "Budget 60 s", "intent": "risk"]],
            ]),
        ChartDemo(
            title: "line-stepped", type: "LineChart",
            props: ["data": ChartGalleryData.wall, "x": "run", "y": "secs", "series": "kind", "curve": "step", "points": "never"]),
            ])
    }
}

struct AreaChartPage: View {
    static let title = "AreaChart"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "Totals and their parts: overlap, stacked (the top edge is the total), 100 % share.",
            demos: [
        ChartDemo(title: "area-overlap", type: "AreaChart", props: ["data": ChartGalleryData.tokens, "x": "day", "y": "k", "series": "agent", "unit": "k"]),
        ChartDemo(
            title: "area-stacked", type: "AreaChart",
            props: [
                "data": ChartGalleryData.tokens, "x": "day", "y": "k", "series": "agent", "layout": "stacked",
                "title": "Tokens per agent, this week",
            ]),
        ChartDemo(
            title: "area-normalized", type: "AreaChart",
            props: ["data": ChartGalleryData.tokens, "x": "day", "y": "k", "series": "agent", "layout": "normalized"]),
            ])
    }
}

struct PieChartPage: View {
    static let title = "PieChart"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "Parts of one whole: pie, donut with a centre text, and one slice shown as a single value.",
            demos: [
        ChartDemo(title: "pie-pie", type: "PieChart", props: ["data": ChartGalleryData.memory, "label": "part", "value": "mb", "unit": "MB"]),
        ChartDemo(
            title: "pie-donut", type: "PieChart",
            props: [
                "data": ChartGalleryData.memory, "label": "part", "value": "mb", "donut": true, "unit": "MB",
                "center": ["value": "138 MB", "label": "resident"], "title": "Where the memory goes",
            ]),
        ChartDemo(
            title: "pie-single", type: "PieChart",
            props: ["data": [["part": "Editor", "mb": 36]], "label": "part", "value": "mb", "unit": "MB"]),
            ])
    }
}

struct GaugePage: View {
    static let title = "Gauge"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "One value against a range: arc with bands, ring, linear with bands and a target.",
            demos: [
        ChartDemo(
            title: "gauge-arc", type: "Gauge",
            props: [
                "value": 3.6, "max": 5, "format": "currency:USD", "label": "Voice budget",
                "bands": [["to": 3.5, "intent": "good"], ["to": 4.5, "intent": "warn"], ["to": 5, "intent": "risk"]],
            ]),
        ChartDemo(
            title: "gauge-ring", type: "Gauge",
            props: ["value": 86, "max": 100, "format": "percent", "label": "Coverage", "style": "ring"]),
        ChartDemo(
            title: "gauge-linear", type: "Gauge",
            props: [
                "value": 47, "max": 100, "target": 80, "format": "percent", "label": "CPU",
                "style": "linear",
                "bands": [["to": 60, "intent": "good"], ["to": 85, "intent": "warn"], ["to": 100, "intent": "risk"]],
            ]),
            ])
    }
}

struct SparklinePage: View {
    static let title = "Sparkline"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "A tiny trend with no axes: line, filled with the maximum marked, a risk status.",
            demos: [
        ChartDemo(title: "sparkline-line", type: "Sparkline", props: ["values": [8, 10, 6, 14, 12, 16, 18, 20, 22]]),
        ChartDemo(
            title: "sparkline-filled", type: "Sparkline",
            props: ["values": [8, 10, 6, 14, 12, 16, 18, 20, 22], "filled": true, "emphasis": "max"]),
        ChartDemo(
            title: "sparkline-risk", type: "Sparkline",
            props: ["values": [3, 4, 4, 5, 7, 6, 9], "intent": "risk"]),
            ])
    }
}

struct ScatterChartPage: View {
    static let title = "ScatterChart"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "Two measures: points, bubbles sized by a field, a linear fit.",
            demos: [
        ChartDemo(title: "scatter-points", type: "ScatterChart", props: ["data": ChartGalleryData.suiteSizes, "x": "tests", "y": "secs", "unit": "s"]),
        ChartDemo(
            title: "scatter-bubble", type: "ScatterChart",
            props: ["data": ChartGalleryData.suiteSizes, "x": "tests", "y": "secs", "size": "cases", "unit": "s"]),
        ChartDemo(
            title: "scatter-fit", type: "ScatterChart",
            props: [
                "data": ChartGalleryData.suiteSizes, "x": "tests", "y": "secs", "trend": "linear", "unit": "s",
                "title": "Suite size against wall time",
            ]),
            ])
    }
}

struct HeatmapPage: View {
    static let title = "Heatmap"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "A grid of values: hours by day, a calendar of weeks by weekdays, a diverging scale.",
            demos: [
        ChartDemo(
            title: "heatmap-grid", type: "Heatmap",
            props: [
                "data": ChartGalleryData.activity, "x": "hour", "y": "day", "value": "n", "title": "Agent activity by hour",
            ]),
        ChartDemo(
            title: "heatmap-calendar", type: "Heatmap",
            props: ["data": ChartGalleryData.calendar, "x": "date", "y": "date", "value": "n", "layout": "calendar"]),
        ChartDemo(
            title: "heatmap-diverging", type: "Heatmap",
            props: [
                "data": .array(
                    (0..<4).flatMap { row in
                        (0..<10).map { col -> JSONValue in
                            ["run": .string("r\(col)"), "suite": .string("s\(row)"), "delta": .number(Double((col * 3 + row * 5) % 11) - 5)]
                        }
                    }),
                "x": "run", "y": "suite", "value": "delta", "scale": "diverging",
            ]),
            ])
    }
}

struct HistogramPage: View {
    static let title = "Histogram"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "A distribution: automatic bins with counts, eight bins as percentages.",
            demos: [
        ChartDemo(
            title: "histogram-count", type: "Histogram",
            props: ["values": ChartGalleryData.durations, "bins": "auto", "unit": "s", "title": "Test duration distribution"]),
        ChartDemo(title: "histogram-percent", type: "Histogram", props: ["values": ChartGalleryData.durations, "bins": 8, "mode": "percent", "format": "duration"]),
            ])
    }
}

struct ComboChartPage: View {
    static let title = "ComboChart"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary: "Bars and a line on one y axis. A second unit is a validator error.",
            demos: [
        ChartDemo(
            title: "combo-bars-line", type: "ComboChart",
            props: ["data": ChartGalleryData.days, "x": "day", "bars": "secs", "line": "avg", "unit": "s", "title": "Wall time and average"])
            ])
    }
}

/// Appends 1,000 points while the chart is marked as streaming: the y domain only grows
/// (1-2-5 steps) and settles once when the stream ends.
struct StreamingSeriesPage: View {
    static let title = "Streaming series"

    @State private var rows: [JSONValue] = []
    @State private var streaming = false
    @State private var run = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.title).font(.title2.weight(.semibold))
                Text(
                    "Appends 1,000 points. While it streams the y domain never shrinks; at the end it settles once to the final nice domain (no animation under Reduce Motion)."
                )
                .foregroundStyle(.secondary)
                HStack {
                    Button(streaming ? "Streaming…" : "Stream 1,000 points") { run += 1 }
                        .disabled(streaming)
                    Text("\(rows.count) points").monospacedDigit().foregroundStyle(.secondary)
                }
                if let factory = ChartGallery.catalog?.viewFactory(for: "LineChart") {
                    factory.make(
                        JRRenderContext(
                            id: "stream",
                            props: [
                                "data": .array(rows), "x": "i", "y": "v", "height": "tall",
                                "title": "Streamed series",
                            ], isStreaming: streaming))
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
        .task(id: run) {
            guard run > 0 else { return }
            await stream()
        }
    }

    private func stream() async {
        rows = []
        streaming = true
        defer { streaming = false }
        let clock = ContinuousClock()
        var peak = 10.0
        for index in 0..<1_000 {
            if Task.isCancelled { return }
            // A noisy series that rises, then falls back near the end.
            peak = index < 800 ? peak + Double(index % 9) * 0.05 : peak * 0.995
            let value = peak + Double((index * 37) % 11)
            rows.append(["i": .number(Double(index)), "v": .number(value)])
            if index % 10 == 9 { try? await clock.sleep(for: .milliseconds(16)) }
        }
    }
}

/// "Show as Table" with a visible button: the same rows in a table.
struct ShowAsTablePage: View {
    static let title = "Show as Table"

    @State private var asTable = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(Self.title).font(.title2.weight(.semibold))
                Text(
                    "Every chart has \"Show as Table\" in its context menu, and ⌘T toggles it while the chart has focus. A host can switch all charts with the jrChartShowsTable environment value, as this button does."
                )
                .foregroundStyle(.secondary)
                Toggle("Show as Table", isOn: $asTable).toggleStyle(.switch)
                VStack(spacing: 16) {
                    ChartDemo(
                        title: "Tests by result", type: "BarChart",
                        props: [
                            "data": ChartGalleryData.runs, "x": "run", "y": "n", "series": "result",
                            "layout": "stacked",
                        ])
                    ChartDemo(
                        title: "Where the memory goes", type: "PieChart",
                        props: [
                            "data": ChartGalleryData.memory, "label": "part", "value": "mb",
                            "donut": true, "unit": "MB",
                        ])
                }
                .environment(\.jrChartShowsTable, asTable)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .topLeading)
        }
    }
}
