public import JSONRenderCore

/// The chart rules `Catalog.validate` runs (registered as the catalog rule `"charts"`).
///
/// Each rule reads the element props: literal `data`, or `{ "$state": … }` data looked up in
/// the spec's initial state. Data that only exists at run time is checked again at render
/// (the chart shows the rule text instead of marks). Issues use `SpecIssue.Code.customRule`
/// with the rule name `charts`, and the message "<Type> <id>: <rule>".
public enum ChartSpecRules {
    public static let name = "charts"

    /// The chart types the rules look at.
    static let chartTypes = Set(ChartKind.allCases.map(\.rawValue))

    /// The rule function for `Catalog.rule`.
    public static let check: SpecRule = { spec, state in issues(in: spec, state: state) }

    /// Every chart issue in `spec`, in element-id order.
    public static func issues(in spec: Spec, state: JSONValue?) -> [SpecIssue] {
        var issues: [SpecIssue] = []
        for id in spec.elements.keys.sorted() {
            guard let element = spec.elements[id], chartTypes.contains(element.type) else {
                continue
            }
            var context = RuleContext(
                id: id, type: element.type, props: element.props, state: state)
            context.run()
            issues += context.issues
        }
        return issues
    }

    struct RuleContext {
        let id: String
        let type: String
        let props: [String: JSONValue]
        let state: JSONValue?
        var issues: [SpecIssue] = []

        mutating func error(_ text: String) { add(.error, text) }
        mutating func warning(_ text: String) { add(.warning, text) }

        private mutating func add(_ severity: SpecIssue.Severity, _ text: String) {
            issues.append(
                SpecIssue(
                    severity: severity, code: .customRule, message: "\(type) \(id): \(text)",
                    elementKey: id, rule: ChartSpecRules.name))
        }

        /// A literal prop value, or the initial-state value a `$state` expression names.
        func resolved(_ name: String) -> JSONValue? {
            guard let value = props[name] else { return nil }
            if case .object(let members) = value, members.count == 1,
                case .string(let path)? = members["$state"]
            {
                guard let pointer = try? JSONPointer(path) else { return nil }
                return state?.value(at: pointer)
            }
            if case .object(let members) = value,
                members.keys.contains(where: { $0.hasPrefix("$") })
            {
                return nil
            }
            return value
        }

        func string(_ name: String) -> String? { props[name]?.stringValue }

        mutating func run() {
            checkFormat()
            checkDomain()
            checkReferenceLines()
            let rows = resolved("data")?.arrayValue
            let values = resolved("values")?.arrayValue
            if let count = rows?.count ?? values?.count, count > ChartBudgets.maxPoints {
                error(
                    "\(count) points; the limit is \(ChartBudgets.maxPoints). Aggregate the data first (groupSum, topN, bucket)."
                )
            }
            if let rows { checkSeries(rows) }
            switch type {
            case ChartKind.pie.rawValue: if let rows { checkPie(rows) }
            case ChartKind.combo.rawValue: checkCombo()
            case ChartKind.heatmap.rawValue: if let rows { checkHeatmap(rows) }
            case ChartKind.funnel.rawValue: if let rows { checkFunnel(rows) }
            case ChartKind.boxPlot.rawValue: if let rows { checkBoxPlot(rows) }
            default: break
            }
        }

        mutating func checkFormat() {
            guard let value = props["format"], case .string(let raw) = value else { return }
            if ChartValueFormat(raw) == nil {
                error(
                    "format \"\(raw)\" is not known; use number, compact, percent, currency:<code>, duration or bytes."
                )
            }
        }

        mutating func checkDomain() {
            for name in ["yDomain", "xDomain"] {
                guard let value = props[name], case .array(let items) = value else { continue }
                let numbers = items.compactMap(\.numberValue)
                if numbers.count != 2 || items.count != 2 {
                    error("\(name) must be [min, max].")
                } else if numbers[0] > numbers[1] {
                    error("\(name) has min greater than max.")
                }
            }
        }

        mutating func checkReferenceLines() {
            guard let lines = resolved("referenceLines")?.arrayValue else { return }
            for (index, line) in lines.enumerated() {
                if ChartValues.number(line["value"]) == nil {
                    error("referenceLines[\(index)] has no numeric value.")
                }
                if line["intent"] != nil, line["label"]?.stringValue?.isEmpty ?? true {
                    warning(
                        "referenceLines[\(index)] has an intent but no label; colour alone does not carry meaning."
                    )
                }
            }
        }

        mutating func checkSeries(_ rows: [JSONValue]) {
            guard let field = string("series") else { return }
            let names = Set(rows.compactMap { ChartValues.text($0[field]) })
            if names.count > ChartBudgets.maxSeries {
                error("\(names.count) series; the limit is \(ChartBudgets.maxSeries).")
            }
        }

        mutating func checkPie(_ rows: [JSONValue]) {
            let labelField = string("label") ?? "label"
            let valueField = string("value") ?? "value"
            var labels = Set<String>()
            var negative = false
            for row in rows {
                guard let label = ChartValues.text(row[labelField]),
                    let value = ChartValues.number(row[valueField])
                else { continue }
                labels.insert(label)
                if value < 0 { negative = true }
            }
            if negative { error("a pie cannot show negative values; use BarChart.") }
            if labels.count > ChartBudgets.maxPieSlices {
                error(
                    "\(labels.count) slices; the limit is \(ChartBudgets.maxPieSlices). Use BarChart."
                )
            } else if labels.count == 1 {
                warning("a pie with one slice; use Gauge or Stat.")
            }
        }

        /// The schema has one `unit`. A list of two or more different units asks for a
        /// second axis.
        mutating func checkCombo() {
            guard case .array(let items)? = props["unit"] else { return }
            if Set(items.compactMap(\.stringValue)).count > 1 {
                error("no dual axis; bars and line share one unit.")
            }
        }

        mutating func checkHeatmap(_ rows: [JSONValue]) {
            let xField = string("x") ?? "x"
            let yField = string("y") ?? "y"
            let columns = Set(rows.compactMap { ChartValues.text($0[xField]) })
            let lines = Set(rows.compactMap { ChartValues.text($0[yField]) })
            let cells = columns.count * max(lines.count, 1)
            if cells > ChartBudgets.maxHeatmapCells {
                error("\(cells) cells; the limit is \(ChartBudgets.maxHeatmapCells).")
            }
        }

        mutating func checkFunnel(_ rows: [JSONValue]) {
            guard props["sort"] == nil else { return }
            let valueField = string("value") ?? "value"
            let values = rows.compactMap { ChartValues.number($0[valueField]) }
            for (index, pair) in zip(values, values.dropFirst()).enumerated() where pair.1 > pair.0
            {
                error(
                    "stage \(index + 2) is larger than the stage before it; set sort: \"none\" to allow it."
                )
                return
            }
        }

        mutating func checkBoxPlot(_ rows: [JSONValue]) {
            let groupField = string("group") ?? "group"
            let groups = Set(rows.compactMap { ChartValues.text($0[groupField]) })
            let limit = CompositeBudgets.maxBoxPlotGroups
            if groups.count > limit { error("\(groups.count) groups; the limit is \(limit).") }
        }
    }
}
