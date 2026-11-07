import Foundation
import JSONRenderCore
import Testing

/// One spec-shaped sample per composite chart variant of VPLAN §7.3 (the site mocks as
/// props).
enum CompositeSamples {
    struct Sample: Sendable, CustomTestStringConvertible {
        let name: String
        let type: String
        let props: [String: JSONValue]

        var testDescription: String { name }
    }

    static let memorySteps: JSONValue = [
        ["label": "Start", "value": 112], ["label": "Terminals", "value": 32],
        ["label": "Editor", "value": 19], ["label": "Pool cap", "value": -24],
        ["label": "Voice", "value": 12], ["label": "Now", "value": 0],
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

    /// 60 directories, for a dense map with small cells and no label.
    static let directories: JSONValue = .array(
        (0..<60).map { index -> JSONValue in
            [
                "dir": .string("dir\(index)"),
                "kb": .number(Double(((index * 37) % 50) + 1) * (index < 5 ? 20 : 1)),
            ]
        })

    static let waterfall: [Sample] = [
        Sample(
            name: "waterfall-vertical", type: "Waterfall",
            props: [
                "data": memorySteps, "label": "label", "value": "value",
                "subtotals": ["Start", "Now"], "unit": "MB",
                "title": "Resident memory, by change",
            ]),
        Sample(
            name: "waterfall-horizontal", type: "Waterfall",
            props: [
                "data": memorySteps, "subtotals": ["Start", "Now"], "orientation": "horizontal",
                "unit": "MB", "height": "tall",
            ]),
        Sample(
            name: "waterfall-start", type: "Waterfall",
            props: [
                "data": [
                    ["phase": "Build", "s": 41], ["phase": "Test", "s": 63],
                    ["phase": "Cache", "s": -18],
                ],
                "label": "phase", "value": "s", "start": 10, "format": "duration",
                "referenceLines": [["value": 90, "label": "Budget", "intent": "risk"]],
            ]),
    ]

    static let funnel: [Sample] = [
        Sample(
            name: "funnel-centred", type: "Funnel",
            props: [
                "data": stages, "label": "stage", "value": "n", "show": "both",
                "title": "Test pipeline, run 4213",
            ]),
        Sample(
            name: "funnel-left", type: "Funnel",
            props: ["data": stages, "label": "stage", "value": "n", "align": "start"]),
        Sample(
            name: "funnel-percent", type: "Funnel",
            props: ["data": stages, "label": "stage", "value": "n", "show": "percent"]),
    ]

    static let boxPlot: [Sample] = [
        Sample(
            name: "boxplot-vertical", type: "BoxPlot",
            props: ["data": suites, "group": "suite", "unit": "s", "title": "Duration by suite"]),
        Sample(
            name: "boxplot-horizontal", type: "BoxPlot",
            props: ["data": suites, "group": "suite", "unit": "s", "orientation": "horizontal"]),
        Sample(
            name: "boxplot-no-outliers", type: "BoxPlot",
            props: ["data": suites, "group": "suite", "format": "duration", "showOutliers": false]),
    ]

    static let candlestick: [Sample] = [
        Sample(
            name: "candlestick-candles", type: "Candlestick",
            props: [
                "data": spend, "x": "day", "format": "currency:USD",
                "title": "Voice spend, USD per day",
            ]),
        Sample(
            name: "candlestick-ohlc", type: "Candlestick",
            props: ["data": spend, "x": "day", "format": "currency:USD", "mark": "ohlc"]),
        Sample(
            name: "candlestick-dates", type: "Candlestick",
            props: ["data": buildDays, "x": "day", "unit": "s", "height": "tall"]),
    ]

    static let treemap: [Sample] = [
        Sample(
            name: "treemap-grouped", type: "Treemap",
            props: [
                "data": modules, "label": "module", "value": "lines", "group": "area",
                "format": "compact", "title": "Source lines by module",
            ]),
        Sample(
            name: "treemap-flat", type: "Treemap",
            props: [
                "data": modules, "label": "module", "value": "lines", "group": "area",
                "maxDepth": 1,
            ]),
        Sample(
            name: "treemap-one-hue", type: "Treemap",
            props: [
                "data": directories, "label": "dir", "value": "kb", "unit": "KB", "height": "tall",
            ]),
        Sample(
            name: "treemap-single", type: "Treemap",
            props: [
                "data": [["module": "RafuApp", "lines": 41]], "label": "module", "value": "lines",
            ]),
    ]

    static var all: [Sample] { waterfall + funnel + boxPlot + candlestick + treemap }
}
