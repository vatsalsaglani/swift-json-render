// Owner: jr-3d (wave 2). One page per composite chart (VPLAN §7.3 variants). Each page has
// `static let title` and `init()`; the coordinator adds the `GalleryPage` conformances and
// the `GalleryPages.all` lines when jr-3's shell is on main.
import Foundation
import JSONRenderCharts
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI

/// Sample data for the composite chart pages (the VPLAN §7.3 mocks as props).
enum CompositeGalleryData {
    static let memorySteps: JSONValue = [
        ["label": "Start", "value": 112], ["label": "Terminals", "value": 32],
        ["label": "Editor", "value": 19], ["label": "Pool cap", "value": -24],
        ["label": "Voice", "value": 12], ["label": "Now", "value": 0],
    ]

    static let phases: JSONValue = [
        ["phase": "Build", "s": 41], ["phase": "Test", "s": 63], ["phase": "Cache hit", "s": -18],
        ["phase": "Lint", "s": 6], ["phase": "Total", "s": 0],
    ]

    static let stages: JSONValue = [
        ["stage": "Collected", "n": 1296], ["stage": "Ran", "n": 1284],
        ["stage": "Passed", "n": 1277], ["stage": "Slow (> 1 s)", "n": 79],
    ]

    static let suites: JSONValue = [
        ["suite": "Canvas", "values": [1.2, 1.4, 1.8, 2.1, 2.4, 2.6, 3.1, 3.4, 9.5]],
        ["suite": "Voice", "values": [0.8, 1.1, 1.3, 1.6, 2.2, 2.4, 2.9]],
        ["suite": "LSP", "values": [2.1, 2.4, 2.9, 3.3, 3.8, 4.4, 5.1, 7.9]],
        [
            "suite": "MDX", "min": 0.4, "q1": 0.7, "median": 0.9, "q3": 1.2, "max": 1.7,
            "outliers": [3.1],
        ],
    ]

    static let spend: JSONValue = [
        ["day": "D1", "open": 10, "high": 12, "low": 9, "close": 11],
        ["day": "D2", "open": 11, "high": 13, "low": 10, "close": 12.5],
        ["day": "D3", "open": 12.5, "high": 14, "low": 11, "close": 11.5],
        ["day": "D4", "open": 11.5, "high": 12, "low": 9.5, "close": 10],
        ["day": "D5", "open": 10, "high": 11, "low": 9, "close": 10.8],
        ["day": "D6", "open": 10.8, "high": 13, "low": 10.5, "close": 12.6],
        ["day": "D7", "open": 12.6, "high": 15, "low": 12, "close": 14.5],
        ["day": "D8", "open": 14.5, "high": 15.5, "low": 13, "close": 13.2],
        ["day": "D9", "open": 13.2, "high": 14, "low": 12.4, "close": 13.9],
        ["day": "D10", "open": 13.9, "high": 16, "low": 13.5, "close": 15.4],
    ]

    /// 30 days of build times with ISO dates (a time axis).
    static let buildDays: JSONValue = .array(
        (0..<30).map { day -> JSONValue in
            let base = 40 + Double((day * 7) % 13)
            let open = base + Double(day % 5)
            let close = base + Double((day * 3) % 7)
            return [
                "day": .string(String(format: "2026-10-%02d", day + 1)),
                "open": .number(open), "close": .number(close),
                "high": .number(max(open, close) + Double(day % 4) + 1),
                "low": .number(min(open, close) - Double(day % 3) - 1),
            ]
        })

    static let modules: JSONValue = [
        ["module": "RafuApp", "lines": 41, "area": "App"],
        ["module": "RafuCore", "lines": 16, "area": "Core and tests"],
        ["module": "Tests", "lines": 13, "area": "Core and tests"],
        ["module": "Editor", "lines": 8, "area": "Features"],
        ["module": "Voice", "lines": 6, "area": "Features"],
        ["module": "Other", "lines": 5, "area": "Other"],
    ]

    /// 60 directories: a dense map where most cells have no label.
    static let directories: JSONValue = .array(
        (0..<60).map { index -> JSONValue in
            [
                "dir": .string("dir\(index)"),
                "kb": .number(Double(((index * 37) % 50) + 1) * (index < 5 ? 20 : 1)),
            ]
        })
}

struct WaterfallPage: View {
    static let title = "Waterfall"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary:
                "How a total is built: vertical with subtotals, horizontal, and a start value with a budget line. Grey bars are totals; increases take the accent and decreases the warning hue, each with a sign.",
            demos: [
                ChartDemo(
                    title: "waterfall-vertical", type: "Waterfall",
                    props: [
                        "data": CompositeGalleryData.memorySteps, "subtotals": ["Start", "Now"],
                        "unit": "MB", "title": "Resident memory, by change",
                        "caption": "MB. Grey bars are totals.",
                    ], bindsSelection: true),
                ChartDemo(
                    title: "waterfall-horizontal", type: "Waterfall",
                    props: [
                        "data": CompositeGalleryData.memorySteps, "subtotals": ["Start", "Now"],
                        "orientation": "horizontal", "unit": "MB", "height": "tall",
                    ]),
                ChartDemo(
                    title: "waterfall-start", type: "Waterfall",
                    props: [
                        "data": CompositeGalleryData.phases, "label": "phase", "value": "s",
                        "start": 10, "subtotals": ["Total"], "format": "duration",
                        "referenceLines": [["value": 120, "label": "Budget", "intent": "risk"]],
                    ]),
            ])
    }
}

struct FunnelPage: View {
    static let title = "Funnel"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary:
                "Stages that narrow: centred with the step-to-step percent between rows, left-aligned, and the share of the first stage.",
            demos: [
                ChartDemo(
                    title: "funnel-centred", type: "Funnel",
                    props: [
                        "data": CompositeGalleryData.stages, "label": "stage", "value": "n",
                        "show": "both", "title": "Test pipeline, run 4213",
                    ], bindsSelection: true),
                ChartDemo(
                    title: "funnel-left", type: "Funnel",
                    props: [
                        "data": CompositeGalleryData.stages, "label": "stage", "value": "n",
                        "align": "start",
                    ]),
                ChartDemo(
                    title: "funnel-percent", type: "Funnel",
                    props: [
                        "data": CompositeGalleryData.stages, "label": "stage", "value": "n",
                        "show": "percent",
                    ]),
                ChartDemo(
                    title: "funnel-rule", type: "Funnel",
                    props: [
                        "data": [["stage": "Ran", "n": 10], ["stage": "Passed", "n": 12]],
                        "label": "stage", "value": "n",
                    ]),
            ])
    }
}

struct BoxPlotPage: View {
    static let title = "BoxPlot"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary:
                "A distribution per group from raw values or precomputed quartiles (Tukey hinges, whiskers at 1.5 IQR): vertical, horizontal, and without outliers.",
            demos: [
                ChartDemo(
                    title: "boxplot-vertical", type: "BoxPlot",
                    props: [
                        "data": CompositeGalleryData.suites, "group": "suite", "unit": "s",
                        "title": "Duration by suite",
                    ], bindsSelection: true),
                ChartDemo(
                    title: "boxplot-horizontal", type: "BoxPlot",
                    props: [
                        "data": CompositeGalleryData.suites, "group": "suite", "unit": "s",
                        "orientation": "horizontal",
                    ]),
                ChartDemo(
                    title: "boxplot-no-outliers", type: "BoxPlot",
                    props: [
                        "data": CompositeGalleryData.suites, "group": "suite",
                        "format": "duration", "showOutliers": false,
                    ]),
            ])
    }
}

struct CandlestickPage: View {
    static let title = "Candlestick"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary:
                "Open, high, low and close per period: candles (a down period is hollow), OHLC bars, and a date axis.",
            demos: [
                ChartDemo(
                    title: "candlestick-candles", type: "Candlestick",
                    props: [
                        "data": CompositeGalleryData.spend, "x": "day", "format": "currency:USD",
                        "title": "Voice spend, USD per day",
                    ], bindsSelection: true),
                ChartDemo(
                    title: "candlestick-ohlc", type: "Candlestick",
                    props: [
                        "data": CompositeGalleryData.spend, "x": "day", "format": "currency:USD",
                        "mark": "ohlc",
                    ]),
                ChartDemo(
                    title: "candlestick-dates", type: "Candlestick",
                    props: [
                        "data": CompositeGalleryData.buildDays, "x": "day", "unit": "s",
                        "height": "tall", "title": "Build time per day, October",
                    ]),
            ])
    }
}

struct TreemapPage: View {
    static let title = "Treemap"

    var body: some View {
        ChartVariantsPage(
            title: Self.title,
            summary:
                "Parts of a whole with many parts: grouped (one level of nesting), flat, one hue with many small cells, and one cell shown as a single value. Hover a cell for its value; click to select.",
            demos: [
                ChartDemo(
                    title: "treemap-grouped", type: "Treemap",
                    props: [
                        "data": CompositeGalleryData.modules, "label": "module",
                        "value": "lines", "group": "area", "format": "compact",
                        "title": "Source lines by module",
                    ], bindsSelection: true),
                ChartDemo(
                    title: "treemap-flat", type: "Treemap",
                    props: [
                        "data": CompositeGalleryData.modules, "label": "module",
                        "value": "lines", "group": "area", "maxDepth": 1,
                    ]),
                ChartDemo(
                    title: "treemap-one-hue", type: "Treemap",
                    props: [
                        "data": CompositeGalleryData.directories, "label": "dir", "value": "kb",
                        "unit": "KB", "height": "tall",
                    ]),
                ChartDemo(
                    title: "treemap-single", type: "Treemap",
                    props: [
                        "data": [["module": "RafuApp", "lines": 41]], "label": "module",
                        "value": "lines",
                    ]),
            ])
    }
}
