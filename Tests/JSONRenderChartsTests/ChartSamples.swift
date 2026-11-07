import Foundation
import JSONRenderCore
import Testing

/// One spec-shaped sample per chart variant of VPLAN §7.3 (the site mocks as props).
enum ChartSamples {
    struct Sample: Sendable, CustomTestStringConvertible {
        let name: String
        let type: String
        let props: [String: JSONValue]

        var testDescription: String { name }
    }

    static let runs: JSONValue = .array(
        [
            ("4208", 1210, 7, 12), ("4209", 1225, 3, 12), ("4210", 1230, 9, 10),
            ("4211", 1238, 2, 10), ("4212", 1251, 5, 8), ("4213", 1277, 7, 12),
        ].flatMap { run, passed, failed, skipped -> [JSONValue] in
            [
                ["run": .string(run), "result": "Passed", "n": .number(Double(passed))],
                ["run": .string(run), "result": "Failed", "n": .number(Double(failed))],
                ["run": .string(run), "result": "Skipped", "n": .number(Double(skipped))],
            ]
        })

    static let suites: JSONValue = [
        ["suite": "CanvasBoardState", "secs": 11.2], ["suite": "VoiceSession", "secs": 8.6],
        ["suite": "LanguageServer", "secs": 6.7], ["suite": "MDXBlockScanner", "secs": 3.8],
        ["suite": "Terminal", "secs": 1.4], ["suite": "Search", "secs": 0.8],
        ["suite": "Theme", "secs": 0.5],
    ]

    static let bar: [Sample] = [
        Sample(
            name: "bar-grouped", type: "BarChart",
            props: [
                "data": runs, "x": "run", "y": "n", "series": "result", "format": "compact",
                "title": "Tests by result, last 6 runs",
            ]),
        Sample(
            name: "bar-stacked", type: "BarChart",
            props: [
                "data": runs, "x": "run", "y": "n", "series": "result", "layout": "stacked",
                "format": "compact",
            ]),
        Sample(
            name: "bar-normalized", type: "BarChart",
            props: ["data": runs, "x": "run", "y": "n", "series": "result", "layout": "normalized"]),
        Sample(
            name: "bar-ranked", type: "BarChart",
            props: [
                "data": suites, "x": "suite", "y": "secs", "orientation": "horizontal",
                "sort": "desc", "limit": 4, "unit": "s", "title": "Slowest suites",
                "caption": "Seconds per suite, top 4 of 7.",
            ]),
        Sample(
            name: "bar-reference", type: "BarChart",
            props: [
                "data": suites, "x": "suite", "y": "secs", "limit": 5,
                "referenceLines": [["value": 10, "label": "Budget", "intent": "risk"]],
                "selection": "VoiceSession",
            ]),
        Sample(
            name: "bar-empty", type: "BarChart", props: ["data": [], "emptyText": "No runs yet"]),
    ]

    static let wall: JSONValue = .array(
        [
            (41, 80), (38, 84), (44, 90), (37, 86), (40, 88), (34, 79), (39, 83), (35, 81),
            (38, 85), (42, 92), (41, 87), (36, 82),
        ].enumerated().flatMap { index, pair -> [JSONValue] in
            let run = JSONValue.string(String(4202 + index))
            return [
                ["run": run, "kind": "Parallel", "secs": .number(Double(pair.0))],
                ["run": run, "kind": "Serial ÷ 2", "secs": .number(Double(pair.1) / 2)],
            ]
        })

    static let tokens: JSONValue = .array(
        ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].enumerated().flatMap {
            index, day -> [JSONValue] in
            let base = Double(index)
            return [
                ["day": .string(day), "agent": "Claude", "k": .number(30 + base * 5)],
                ["day": .string(day), "agent": "Codex", "k": .number(12 + base * 2)],
                ["day": .string(day), "agent": "Voice", "k": .number(6 + base)],
            ]
        })

    static let daily: JSONValue = .array(
        (1...28).map { day -> JSONValue in
            let text = String(format: "2026-10-%02d", day)
            return [
                "day": .string(text),
                "secs": .number(40 + Double((day * 7) % 11) - Double(day) / 4),
            ]
        })

    static let memory: JSONValue = [
        ["part": "Terminals", "mb": 61], ["part": "Editor", "mb": 36], ["part": "Board", "mb": 19],
        ["part": "Voice", "mb": 12], ["part": "Search", "mb": 6], ["part": "Git", "mb": 3],
        ["part": "Theme", "mb": 1],
    ]

    static let suiteSizes: JSONValue = [
        ["suite": "Canvas", "tests": 61, "secs": 11.2, "cases": 61],
        ["suite": "Voice", "tests": 38, "secs": 8.6, "cases": 38],
        ["suite": "LSP", "tests": 54, "secs": 6.7, "cases": 54],
        ["suite": "MDX", "tests": 27, "secs": 3.8, "cases": 27],
        ["suite": "Term", "tests": 18, "secs": 1.4, "cases": 18],
        ["suite": "Search", "tests": 33, "secs": 2.2, "cases": 33],
        ["suite": "Git", "tests": 72, "secs": 9.9, "cases": 72],
        ["suite": "Theme", "tests": 12, "secs": 0.6, "cases": 12],
    ]

    static let activity: JSONValue = .array(
        ["Mon", "Tue", "Wed", "Thu"].enumerated().flatMap { row, day -> [JSONValue] in
            (8...19).map { hour -> JSONValue in
                let value = Double(((hour * 7 + row * 5) % 13))
                return [
                    "hour": .string(String(format: "%02d:00", hour)), "day": .string(day),
                    "n": .number(value),
                ]
            }
        })

    static let calendar: JSONValue = .array(
        (0..<56).map { offset -> JSONValue in
            let day = 1 + offset
            let month = day > 31 ? 11 : 10
            let date = String(format: "2026-%02d-%02d", month, day > 31 ? day - 31 : day)
            return ["date": .string(date), "n": .number(Double((offset * 5) % 9))]
        })

    static let durations: JSONValue = [
        6.1, 2.7, 1.4, 2.5, 1.7, 2.5, 2, 2, 2.5, 1.5, 3.1, 5.8, 2.7, 0.6, 3, 1.3, 2.7, 1.8, 2.4,
        2.4, 1.6, 3, 6.4, 3.2, 0.8, 3.3, 1.4, 3, 1.6, 2.5, 1.9, 2.5, 2.3, 6.4, 2.6, 1.1, 2.6, 1,
        2.9, 1.4, 2.8, 2.3, 2.5, 2.4, 6.7, 3.1, 1.7, 3,
    ]

    static let days: JSONValue = [
        ["day": "Mon", "secs": 41, "avg": 40], ["day": "Tue", "secs": 38, "avg": 40],
        ["day": "Wed", "secs": 44, "avg": 41], ["day": "Thu", "secs": 37, "avg": 40],
        ["day": "Fri", "secs": 52, "avg": 43], ["day": "Sat", "secs": 34, "avg": 42],
        ["day": "Sun", "secs": 36, "avg": 41],
    ]

    static let line: [Sample] = [
        Sample(
            name: "line-single", type: "LineChart",
            props: [
                "data": daily, "x": "day", "y": "secs", "unit": "s", "title": "Wall time, October",
            ]),
        Sample(
            name: "line-multi", type: "LineChart",
            props: [
                "data": wall, "x": "run", "y": "secs", "series": "kind", "unit": "s",
                "title": "Wall time, last 12 runs",
                "referenceLines": [["value": 60, "label": "Budget 60 s", "intent": "risk"]],
            ]),
        Sample(
            name: "line-stepped", type: "LineChart",
            props: [
                "data": wall, "x": "run", "y": "secs", "series": "kind", "curve": "step",
                "points": "never",
            ]),
    ]

    static let area: [Sample] = [
        Sample(
            name: "area-overlap", type: "AreaChart",
            props: ["data": tokens, "x": "day", "y": "k", "series": "agent", "unit": "k"]),
        Sample(
            name: "area-stacked", type: "AreaChart",
            props: [
                "data": tokens, "x": "day", "y": "k", "series": "agent", "layout": "stacked",
                "title": "Tokens per agent, this week",
            ]),
        Sample(
            name: "area-normalized", type: "AreaChart",
            props: [
                "data": tokens, "x": "day", "y": "k", "series": "agent", "layout": "normalized",
            ]),
    ]

    static let pie: [Sample] = [
        Sample(
            name: "pie-pie", type: "PieChart",
            props: ["data": memory, "label": "part", "value": "mb", "unit": "MB"]),
        Sample(
            name: "pie-donut", type: "PieChart",
            props: [
                "data": memory, "label": "part", "value": "mb", "donut": true, "unit": "MB",
                "center": ["value": "138 MB", "label": "resident"],
                "title": "Where the memory goes",
            ]),
        Sample(
            name: "pie-single", type: "PieChart",
            props: [
                "data": [["part": "Editor", "mb": 36]], "label": "part", "value": "mb",
                "unit": "MB",
            ]),
    ]

    static let gauge: [Sample] = [
        Sample(
            name: "gauge-arc", type: "Gauge",
            props: [
                "value": 3.6, "max": 5, "format": "currency:USD", "label": "Voice budget",
                "bands": [
                    ["to": 3.5, "intent": "good"], ["to": 4.5, "intent": "warn"],
                    ["to": 5, "intent": "risk"],
                ],
            ]),
        Sample(
            name: "gauge-ring", type: "Gauge",
            props: [
                "value": 86, "max": 100, "format": "percent", "label": "Coverage", "style": "ring",
            ]),
        Sample(
            name: "gauge-linear", type: "Gauge",
            props: [
                "value": 47, "max": 100, "target": 80, "format": "percent", "label": "CPU",
                "style": "linear",
                "bands": [
                    ["to": 60, "intent": "good"], ["to": 85, "intent": "warn"],
                    ["to": 100, "intent": "risk"],
                ],
            ]),
    ]

    static let sparkline: [Sample] = [
        Sample(
            name: "sparkline-line", type: "Sparkline",
            props: ["values": [8, 10, 6, 14, 12, 16, 18, 20, 22]]),
        Sample(
            name: "sparkline-filled", type: "Sparkline",
            props: [
                "values": [8, 10, 6, 14, 12, 16, 18, 20, 22], "filled": true, "emphasis": "max",
            ]),
        Sample(
            name: "sparkline-risk", type: "Sparkline",
            props: ["values": [3, 4, 4, 5, 7, 6, 9], "intent": "risk"]),
    ]

    static let scatter: [Sample] = [
        Sample(
            name: "scatter-points", type: "ScatterChart",
            props: ["data": suiteSizes, "x": "tests", "y": "secs", "unit": "s"]),
        Sample(
            name: "scatter-bubble", type: "ScatterChart",
            props: ["data": suiteSizes, "x": "tests", "y": "secs", "size": "cases", "unit": "s"]),
        Sample(
            name: "scatter-fit", type: "ScatterChart",
            props: [
                "data": suiteSizes, "x": "tests", "y": "secs", "trend": "linear", "unit": "s",
                "title": "Suite size against wall time",
            ]),
    ]

    static let heatmap: [Sample] = [
        Sample(
            name: "heatmap-grid", type: "Heatmap",
            props: [
                "data": activity, "x": "hour", "y": "day", "value": "n",
                "title": "Agent activity by hour",
            ]),
        Sample(
            name: "heatmap-calendar", type: "Heatmap",
            props: ["data": calendar, "x": "date", "y": "date", "value": "n", "layout": "calendar"]),
        Sample(
            name: "heatmap-diverging", type: "Heatmap",
            props: [
                "data": .array(
                    (0..<4).flatMap { row in
                        (0..<10).map { col -> JSONValue in
                            [
                                "run": .string("r\(col)"), "suite": .string("s\(row)"),
                                "delta": .number(Double((col * 3 + row * 5) % 11) - 5),
                            ]
                        }
                    }),
                "x": "run", "y": "suite", "value": "delta", "scale": "diverging",
            ]),
    ]

    static let histogram: [Sample] = [
        Sample(
            name: "histogram-count", type: "Histogram",
            props: [
                "values": durations, "bins": "auto", "unit": "s",
                "title": "Test duration distribution",
            ]),
        Sample(
            name: "histogram-percent", type: "Histogram",
            props: ["values": durations, "bins": 8, "mode": "percent", "format": "duration"]),
    ]

    static let combo: [Sample] = [
        Sample(
            name: "combo-bars-line", type: "ComboChart",
            props: [
                "data": days, "x": "day", "bars": "secs", "line": "avg", "unit": "s",
                "title": "Wall time and average",
            ])
    ]

    static var all: [Sample] {
        bar + line + area + pie + gauge + sparkline + scatter + heatmap + histogram + combo
    }
}
