import JSONRenderCore
import Testing

@testable import JSONRenderCharts

@Suite("Chart validator rules")
struct ChartSpecRulesTests {
    func issues(
        _ type: String, _ props: [String: JSONValue], state: JSONValue? = nil
    ) -> [SpecIssue] {
        let spec = Spec(
            root: "c", elements: ["c": UIElement(type: type, props: props)], state: state)
        return ChartSpecRules.issues(in: spec, state: state)
    }

    func messages(_ type: String, _ props: [String: JSONValue], state: JSONValue? = nil) -> [String]
    {
        issues(type, props, state: state).map(\.message)
    }

    static let slices: JSONValue = [["l": "a", "v": 3], ["l": "b", "v": 2]]

    @Test("Pie: negative values")
    func pieNegative() {
        #expect(
            messages(
                "PieChart",
                ["data": [["l": "a", "v": -1], ["l": "b", "v": 2]], "label": "l", "value": "v"])
                == ["PieChart c: a pie cannot show negative values; use BarChart."])
        #expect(messages("PieChart", ["data": Self.slices, "label": "l", "value": "v"]).isEmpty)
    }

    @Test("Pie: more than 12 slices, and one slice")
    func pieCounts() {
        let many = JSONValue.array((0..<13).map { ["l": .string("s\($0)"), "v": 1] })
        #expect(
            messages("PieChart", ["data": many, "label": "l", "value": "v"])
                == ["PieChart c: 13 slices; the limit is 12. Use BarChart."])
        let one = issues("PieChart", ["data": [["l": "a", "v": 1]], "label": "l", "value": "v"])
        #expect(one.map(\.severity) == [.warning])
        #expect(one.first?.message == "PieChart c: a pie with one slice; use Gauge or Stat.")
    }

    @Test("Pie data from the initial state is checked")
    func stateData() {
        let state: JSONValue = ["mem": [["l": "a", "v": -2], ["l": "b", "v": 3]]]
        #expect(
            issues(
                "PieChart", ["data": ["$state": "/mem"], "label": "l", "value": "v"], state: state
            )
            .count == 1)
        #expect(
            issues(
                "PieChart", ["data": ["$state": "/missing"], "label": "l", "value": "v"],
                state: state
            )
            .isEmpty)
    }

    @Test("Combo: no dual axis")
    func combo() {
        #expect(
            messages("ComboChart", ["unit": ["s", "%"]])
                == ["ComboChart c: no dual axis; bars and line share one unit."])
        #expect(messages("ComboChart", ["unit": "s"]).isEmpty)
        #expect(messages("ComboChart", ["unit": ["s", "s"]]).isEmpty)
    }

    @Test("Funnel: a larger stage needs sort none")
    func funnel() {
        let rising: JSONValue = [["value": 10], ["value": 12]]
        #expect(
            messages("Funnel", ["data": rising])
                == [
                    "Funnel c: stage 2 is larger than the stage before it; set sort: \"none\" to allow it."
                ])
        #expect(messages("Funnel", ["data": rising, "sort": "none"]).isEmpty)
        #expect(messages("Funnel", ["data": [["value": 12], ["value": 10]]]).isEmpty)
    }

    @Test("Points over 5,000")
    func points() {
        let rows = JSONValue.array(Array(repeating: ["x": "a", "y": 1], count: 5_001))
        #expect(messages("LineChart", ["data": rows]).first?.contains("5001 points") == true)
        let ok = JSONValue.array(Array(repeating: ["x": "a", "y": 1], count: 5_000))
        #expect(messages("LineChart", ["data": ok]).isEmpty)
    }

    @Test("Series over 12")
    func series() {
        let rows = JSONValue.array((0..<13).map { ["s": .string("s\($0)")] })
        #expect(
            messages("BarChart", ["data": rows, "series": "s"]) == [
                "BarChart c: 13 series; the limit is 12."
            ])
        let twelve = JSONValue.array((0..<12).map { ["s": .string("s\($0)")] })
        #expect(messages("BarChart", ["data": twelve, "series": "s"]).isEmpty)
    }

    @Test("Heatmap cells over 2,500")
    func heatmap() {
        let rows = JSONValue.array(
            (0..<51).flatMap { x in
                (0..<50).map { y in ["x": .number(Double(x)), "y": .number(Double(y))] }
            })
        #expect(
            messages("Heatmap", ["data": rows]) == ["Heatmap c: 2550 cells; the limit is 2500."])
        let small = JSONValue.array((0..<50).map { x in ["x": .number(Double(x)), "y": 1] })
        #expect(messages("Heatmap", ["data": small]).isEmpty)
    }

    @Test("BoxPlot groups over 20")
    func boxPlot() {
        let rows = JSONValue.array((0..<21).map { ["group": .string("g\($0)")] })
        #expect(messages("BoxPlot", ["data": rows]) == ["BoxPlot c: 21 groups; the limit is 20."])
        #expect(messages("BoxPlot", ["data": [["group": "a"]]]).isEmpty)
    }

    @Test("Unknown format")
    func format() {
        #expect(messages("BarChart", ["format": "money"]).count == 1)
        #expect(messages("BarChart", ["format": "currency:USD"]).isEmpty)
    }

    @Test("yDomain shape and order")
    func domain() {
        #expect(
            messages("LineChart", ["yDomain": [10, 0]]) == [
                "LineChart c: yDomain has min greater than max."
            ])
        #expect(
            messages("LineChart", ["yDomain": [0]]) == ["LineChart c: yDomain must be [min, max]."])
        #expect(messages("LineChart", ["yDomain": [0, 10]]).isEmpty)
    }

    @Test("Reference lines: value required; intent needs a label")
    func referenceLines() {
        #expect(
            messages("LineChart", ["referenceLines": [["label": "Budget"]]])
                == ["LineChart c: referenceLines[0] has no numeric value."])
        let colourOnly = issues("LineChart", ["referenceLines": [["value": 60, "intent": "risk"]]])
        #expect(colourOnly.map(\.severity) == [.warning])
        #expect(
            messages(
                "LineChart",
                ["referenceLines": [["value": 60, "label": "Budget", "intent": "risk"]]]
            )
            .isEmpty)
    }

    @Test("Issues carry the rule name, the element id and the custom-rule code")
    func shape() {
        let issue = issues("BarChart", ["format": "money"]).first
        #expect(issue?.code == .customRule)
        #expect(issue?.rule == "charts")
        #expect(issue?.elementKey == "c")
    }

    @Test("Catalog.validate runs the chart rule")
    func throughCatalog() throws {
        let catalog = try Catalog.charts
        let spec = Spec(
            root: "c",
            elements: [
                "c": UIElement(
                    type: "BarChart", props: ["data": [], "x": "a", "y": "b", "format": "money"])
            ])
        let report = catalog.validate(spec)
        #expect(report.errors.contains { $0.rule == "charts" })
        #expect(!report.valid)
    }

    @Test("Non-chart elements are ignored")
    func ignoresOthers() {
        #expect(messages("Card", ["format": "money"]).isEmpty)
    }
}
