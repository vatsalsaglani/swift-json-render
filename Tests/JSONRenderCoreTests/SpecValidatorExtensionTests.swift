import Foundation
import Testing

@testable import JSONRenderCore

private let textCatalog = Catalog(components: [
    ComponentDefinition(
        name: "Text",
        props: .object([
            .init(name: "text", schema: .string),
            .init(name: "size", schema: PropSchema.enum(["sm", "lg"]).nullable()),
        ])),
    ComponentDefinition(name: "Stack", slots: ["default"]),
])

private func chain(_ count: Int) -> Spec {
    var elements: [String: UIElement] = [:]
    for index in 0..<count {
        elements["e\(index)"] = UIElement(
            type: "Stack", children: index + 1 < count ? ["e\(index + 1)"] : [])
    }
    return Spec(root: "e0", elements: elements)
}

@Suite("Spec validator extensions")
struct SpecValidatorExtensionTests {
    @Test("Unknown component is an error; an empty catalog skips the check")
    func unknownComponent() {
        let spec = Spec(root: "a", elements: ["a": UIElement(type: "Nope")])
        #expect(textCatalog.validate(spec).issues.map(\.code) == [.unknownComponent])
        #expect(Catalog().validate(spec).valid)
    }

    @Test("Prop type failures; expressions and null for nullable pass")
    func props() {
        let bad = Spec(root: "a", elements: ["a": UIElement(type: "Text", props: ["text": 3])])
        let issues = textCatalog.validate(bad).issues
        #expect(issues.map(\.code) == [.invalidProps])
        #expect(issues.first?.message.contains("prop \"text\"") == true)
        let good = Spec(
            root: "a",
            elements: [
                "a": UIElement(type: "Text", props: ["text": ["$state": "/t"], "size": .null])
            ])
        #expect(textCatalog.validate(good).valid)
        let missing = Spec(
            root: "a", elements: ["a": UIElement(type: "Text", props: ["size": "sm"])])
        #expect(textCatalog.validate(missing).issues.map(\.code) == [.invalidProps])
        // An absent nullable prop passes (see PropSchema.validate).
        let absent = Spec(root: "a", elements: ["a": UIElement(type: "Text", props: ["text": "t"])])
        #expect(textCatalog.validate(absent).valid)
    }

    @Test("A cycle a→b→a is reported once and the plan stops")
    func cycle() {
        let spec = Spec(
            root: "a",
            elements: [
                "a": UIElement(type: "Stack", children: ["b"]),
                "b": UIElement(type: "Stack", children: ["a"]),
            ])
        let report = textCatalog.validate(spec)
        #expect(report.issues.filter { $0.code == .cycle }.count == 1)
        #expect(RenderPlan(spec: spec).cycles == [["a", "b"]])
        #expect(RenderPlan(spec: spec).order == ["a", "b"])
    }

    @Test("Depth 65 is marked")
    func depth() {
        let spec = chain(67)
        let report = textCatalog.validate(spec)
        #expect(report.issues.filter { $0.code == .depthExceeded }.map(\.elementKey) == ["e65"])
        let plan = RenderPlan(spec: spec)
        #expect(plan.truncatedAtDepth == ["e65"])
        #expect(plan.nodes["e66"] == nil)
    }

    @Test("2,001 elements exceed the cap")
    func elementCount() {
        var elements: [String: UIElement] = ["root": UIElement(type: "Stack")]
        for index in 0..<2_000 { elements["x\(index)"] = UIElement(type: "Stack") }
        let report = textCatalog.validate(Spec(root: "root", elements: elements))
        #expect(report.issues.map(\.code) == [.tooManyElements])
    }

    @Test("501 repeat rows give a warning")
    func repeatRows() {
        let spec = Spec(
            root: "list",
            elements: [
                "list": UIElement(
                    type: "Stack", children: ["row"],
                    repeat: RepeatConfig(statePath: .absolute("/rows"))),
                "row": UIElement(type: "Stack"),
            ],
            state: ["rows": .array(Array(repeating: 1, count: 501))])
        let report = textCatalog.validate(spec)
        #expect(report.valid)
        #expect(report.warnings.map(\.code) == [.tooManyRepeatRows])
    }

    @Test("256 KiB + 1 bytes: decode error, and spec_too_large from validate(data:)")
    func tooLarge() throws {
        let data = Data(repeating: 0x20, count: SpecLimits.defaultMaxBytes + 1)
        #expect(throws: SpecDecodeError.self) { try Spec.decode(data) }
        let report = try textCatalog.validate(data: data)
        #expect(report.issues.map(\.code) == [.specTooLarge])
    }

    @Test("Catalog rules run after the built-in checks and are named")
    func rules() {
        var catalog = textCatalog
        catalog.rule("noEmptyText") { spec, _ in
            spec.elements.keys.sorted().compactMap { key in
                guard spec.elements[key]?.props["text"] == "" else { return nil }
                return SpecIssue(
                    severity: .warning, code: .customRule, message: "Empty text", elementKey: key)
            }
        }
        let spec = Spec(root: "a", elements: ["a": UIElement(type: "Text", props: ["text": ""])])
        let report = catalog.validate(spec)
        #expect(report.valid)
        #expect(report.warnings.first?.rule == "noEmptyText")
        #expect(
            catalog.validate(spec, options: ValidateSpecOptions(checkRules: false)).issues.isEmpty)
    }

    @Test("formatted() lists only errors")
    func formatted() {
        let report = ValidationReport(issues: [
            SpecIssue(severity: .error, code: .missingRoot, message: "A"),
            SpecIssue(severity: .warning, code: .orphanedElement, message: "B"),
        ])
        #expect(report.formatted() == "The generated UI spec has the following errors:\n- A")
        #expect(ValidationReport(issues: []).formatted() == "")
    }

    @Test("autoFix prunes dangling children and slots; the 2-tuple form matches")
    func autoFixPrunes() {
        let spec = Spec(
            root: "a",
            elements: [
                "a": UIElement(
                    type: "Stack", children: ["b", "ghost"], slots: ["header": ["gone"]]),
                "b": UIElement(type: "Stack"),
            ])
        let (fixed, fixes) = Catalog.autoFix(spec)
        #expect(fixed.elements["a"]?.children == ["b"])
        #expect(fixed.elements["a"]?.slots == ["header": []])
        #expect(fixes.count == 2)
        #expect(RenderPlan(spec: fixed).dangling.isEmpty)
    }
}

@Suite("RenderPlan")
struct RenderPlanTests {
    @Test("Order is depth-first, children before slots; dangling ids collected")
    func order() {
        let spec = Spec(
            root: "root",
            elements: [
                "root": UIElement(
                    type: "Card", children: ["a", "missing"],
                    slots: ["footer": ["f"], "header": ["h"]]),
                "a": UIElement(type: "Text", children: ["a1"]),
                "a1": UIElement(type: "Text"),
                "f": UIElement(type: "Text"),
                "h": UIElement(type: "Text"),
                "orphan": UIElement(type: "Text"),
            ])
        let plan = RenderPlan(spec: spec)
        #expect(plan.rootID == "root")
        #expect(plan.order == ["root", "a", "a1", "f", "h"])
        #expect(plan.dangling == ["missing"])
        #expect(plan.nodes["a1"]?.depth == 2)
        #expect(plan.nodes["root"]?.childIDs == ["a", "missing"])
        #expect(plan.nodes["orphan"] == nil)
    }

    @Test("A missing root is dangling and the plan is empty")
    func missingRoot() {
        let plan = RenderPlan(spec: Spec(root: "main", elements: [:]))
        #expect(plan.rootID == nil)
        #expect(plan.dangling == ["main"])
        #expect(plan.order.isEmpty)
    }

    @Test("A shared child is visited once; repeat is flagged")
    func shared() {
        let spec = Spec(
            root: "r",
            elements: [
                "r": UIElement(
                    type: "S", children: ["x", "y"],
                    repeat: RepeatConfig(statePath: .absolute("/a"))),
                "x": UIElement(type: "S", children: ["z"]),
                "y": UIElement(type: "S", children: ["z"]),
                "z": UIElement(type: "S"),
            ])
        let plan = RenderPlan(spec: spec)
        #expect(plan.order == ["r", "x", "z", "y"])
        #expect(plan.cycles.isEmpty)
        #expect(plan.nodes["r"]?.hasRepeat == true)
    }

    @Test("A lower maxDepth truncates earlier")
    func limits() {
        let plan = RenderPlan(spec: chain(5), limits: SpecLimits(maxDepth: 2))
        #expect(plan.truncatedAtDepth == ["e3"])
        #expect(plan.order == ["e0", "e1", "e2", "e3"])
    }
}

@Suite("Stream types")
struct StreamTypesTests {
    @Test("SpecPatch round-trips every line of the upstream streams")
    func roundTrip() throws {
        let folder = ParityFixtures.url("streams")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { $0.hasSuffix(".jsonl") }.sorted()
        var ops: Set<PatchOperation> = []
        for file in files {
            let text = String(
                decoding: try Data(contentsOf: folder.appendingPathComponent(file)), as: UTF8.self)
            for line in text.split(separator: "\n") where line.hasPrefix("{") {
                guard let patch = try? JSONDecoder().decode(SpecPatch.self, from: Data(line.utf8))
                else { continue }
                ops.insert(patch.op)
                let again = try JSONDecoder().decode(
                    SpecPatch.self, from: JSONEncoder().encode(patch))
                #expect(again == patch)
            }
        }
        #expect(ops.isSuperset(of: [.add, .remove, .replace]))
    }

    @Test("SpecSnapshot builds its plan and takes dangling from it")
    func snapshot() {
        let spec = Spec(root: "a", elements: ["a": UIElement(type: "T", children: ["b"])])
        let snapshot = SpecSnapshot(version: 3, spec: spec)
        #expect(snapshot.plan.order == ["a"])
        #expect(snapshot.dangling == ["b"])
        #expect(!snapshot.isFinal)
        #expect(snapshot.journal.isEmpty)
    }
}
