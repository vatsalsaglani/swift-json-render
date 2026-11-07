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

    static var all: [Sample] { bar }
}
