import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import Testing

@Suite struct ElementResolutionTests {
    let catalog: Catalog

    init() throws {
        catalog = try Catalog.standard
    }

    private func spec(_ json: String) throws -> Spec {
        try Spec.decode(Data(json.utf8)).spec
    }

    @Test func resolvesPropsAndBindings() throws {
        let element = UIElement(
            type: "Tabs",
            props: [
                "value": ["$bindState": "/tab"], "defaultValue": ["$state": "/fallback"],
                "tabs": [["label": "A", "value": "a"]],
            ])
        let state: JSONValue = ["tab": "a", "fallback": "b"]
        let resolved = ElementResolution.resolve(
            element: element, scope: nil, state: state, catalog: catalog)
        #expect(resolved.isVisible)
        #expect(resolved.props["value"] == .some(.string("a")))
        #expect(resolved.props["defaultValue"] == .some(.string("b")))
        #expect(resolved.bindings == ["value": "/tab"])
        #expect(resolved.warnings.isEmpty)
    }

    @Test func undefinedStaysDistinctFromNull() {
        let element = UIElement(
            type: "Text", props: ["text": ["$state": "/missing"], "variant": .null])
        let resolved = ElementResolution.resolve(
            element: element, scope: nil, state: [:], catalog: catalog)
        #expect(resolved.props["text"] == .some(nil))
        #expect(resolved.props["variant"] == .some(.null))
    }

    @Test func hiddenElementResolvesNothing() {
        let element = UIElement(
            type: "Text", props: ["text": "x"],
            visible: VisibilityCondition(json: ["$state": "/show"]))
        let resolved = ElementResolution.resolve(
            element: element, scope: nil, state: ["show": false], catalog: catalog)
        #expect(!resolved.isVisible)
        #expect(resolved.props.isEmpty)
    }

    @Test func bindItemUsesTheRowPath() {
        let scope = RepeatScope(item: ["done": false], index: 2, basePath: "/todos/2")
        let element = UIElement(type: "Text", props: ["text": ["$bindItem": "done"]])
        let resolved = ElementResolution.resolve(
            element: element, scope: scope,
            state: ["todos": [[:], [:], ["done": true]]], catalog: catalog)
        #expect(resolved.bindings["text"] == "/todos/2/done")
        #expect(resolved.props["text"] == .some(.bool(true)))
    }

    @Test func bindItemOutsideRepeatWarns() {
        let element = UIElement(type: "Text", props: ["text": ["$bindItem": "done"]])
        let resolved = ElementResolution.resolve(
            element: element, scope: nil, state: [:], catalog: catalog)
        #expect(resolved.bindings.isEmpty)
        #expect(resolved.warnings == [.bindItemOutsideScope("done")])
    }

    @Test func repeatRowsReadTheArrayWithKeysAndFilter() throws {
        let spec = try spec(
            #"""
            {"root":"list","state":{"items":[{"id":"a","on":true},{"id":"b","on":false},{"id":"c","on":true}]},
             "elements":{"list":{"type":"Stack","repeat":{"statePath":"/items","key":"id"},
               "visible":{"$item":"on"},"children":["t"]},
               "t":{"type":"Text","props":{"text":{"$item":"id"}}}}}
            """#)
        let element = try #require(spec.elements["list"])
        let resolved = ElementResolution.resolve(
            element: element, scope: nil, state: spec.state ?? [:], catalog: catalog)
        #expect(resolved.isVisible)
        let rows = ElementResolution.repeatRows(
            element: element, id: "list", scope: nil, state: spec.state ?? [:],
            itemFilter: resolved.itemFilter, limits: .default)
        #expect(rows.scopes.map(\.index) == [0, 2])
        #expect(rows.scopes.map(\.key) == ["a", "c"])
        #expect(rows.scopes.map(\.basePath) == ["/items/0", "/items/2"])
    }

    @Test func nestedRepeatResolvesAgainstTheEnclosingRow() throws {
        let outer = RepeatScope(item: [:], index: 1, basePath: "/groups/1")
        let element = UIElement(
            type: "Stack", repeat: RepeatConfig(statePath: .item("rows")))
        let state: JSONValue = ["groups": [["rows": []], ["rows": ["x", "y"]]]]
        let rows = ElementResolution.repeatRows(
            element: element, id: "inner", scope: outer, state: state, itemFilter: nil,
            limits: .default)
        #expect(rows.scopes.map(\.basePath) == ["/groups/1/rows/0", "/groups/1/rows/1"])
        #expect(rows.scopes.map(\.item) == ["x", "y"])
    }

    @Test func repeatProblemsWarn() throws {
        let notArray = UIElement(type: "Stack", repeat: RepeatConfig(statePath: .absolute("/n")))
        let rows = ElementResolution.repeatRows(
            element: notArray, id: "s", scope: nil, state: ["n": 3], itemFilter: nil,
            limits: .default)
        #expect(rows.scopes.isEmpty)
        #expect(rows.warnings == [.repeatNotArray(id: "s")])

        let outside = UIElement(type: "Stack", repeat: RepeatConfig(statePath: .item("rows")))
        let invalid = ElementResolution.repeatRows(
            element: outside, id: "s", scope: nil, state: [:], itemFilter: nil, limits: .default)
        #expect(invalid.warnings == [.repeatPathInvalid(id: "s")])

        let many = UIElement(type: "Stack", repeat: RepeatConfig(statePath: .absolute("/a")))
        let limits = SpecLimits(maxRepeatRows: 2)
        let capped = ElementResolution.repeatRows(
            element: many, id: "s", scope: nil, state: ["a": [1, 2, 3]], itemFilter: nil,
            limits: limits)
        #expect(capped.scopes.count == 2)
        #expect(capped.warnings == [.tooManyRows(id: "s", count: 3)])
    }

    @Test func walkReportsCyclesDepthMissingAndUnknownTypes() throws {
        let cyclic = try spec(
            #"""
            {"root":"a","elements":{"a":{"type":"Stack","children":["b","gone"]},
              "b":{"type":"Stack","children":["a"]}}}
            """#)
        let walk = RenderWalk(
            spec: cyclic, plan: RenderPlan(spec: cyclic), state: [:], catalog: catalog)
        #expect(walk.fallbacks.contains(.cycle(id: "a")))
        #expect(walk.fallbacks.contains(.missingElement(id: "gone")))

        var elements: [String: UIElement] = [:]
        for depth in 0..<5 {
            elements["e\(depth)"] = UIElement(type: "Stack", children: ["e\(depth + 1)"])
        }
        elements["e5"] = UIElement(type: "Nope")
        let deep = Spec(root: "e0", elements: elements)
        let limits = SpecLimits(maxDepth: 2)
        let deepWalk = RenderWalk(
            spec: deep, plan: RenderPlan(spec: deep, limits: limits), state: [:],
            catalog: catalog, limits: limits)
        #expect(deepWalk.fallbacks == [.tooDeep(id: "e3")])

        let unknown = Spec(root: "x", elements: ["x": UIElement(type: "Nope")])
        let unknownWalk = RenderWalk(
            spec: unknown, plan: RenderPlan(spec: unknown), state: [:], catalog: catalog)
        #expect(unknownWalk.fallbacks == [.unknownType(id: "x", type: "Nope")])
    }

    @Test func walkRepeatsChildrenPerRowAndWarnsOnce() throws {
        let spec = try spec(
            #"""
            {"root":"list","state":{"items":["a","b","c"]},
             "elements":{"list":{"type":"Stack","repeat":{"statePath":"/items"},"children":["t","u"]},
               "t":{"type":"Text","props":{"text":{"$item":""}}},
               "u":{"type":"Mystery"}}}
            """#)
        let walk = RenderWalk(
            spec: spec, plan: RenderPlan(spec: spec), state: spec.state ?? [:], catalog: catalog)
        #expect(walk.elements.map(\.id) == ["list", "t", "t", "t"])
        #expect(walk.elements.dropFirst().map { $0.props["text"] ?? nil } == ["a", "b", "c"])
        #expect(walk.warnings == [.unknownType(id: "u", type: "Mystery")])
    }
}
