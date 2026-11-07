import Testing

@testable import JSONRenderCore

/// Transcribed from upstream `types.test.ts` 943–1086 (`nestedToFlat`) and React
/// `hooks.ts` 399–430 (`flatToTree`). There are no wave-0 fixtures for these.
@Suite("nestedToFlat and flatToTree parity")
struct NestedToFlatParityTests {
    @Test("converts a single node with no children (types.test.ts:947)")
    func singleNode() {
        let spec = Spec.nestedToFlat(["type": "Text", "props": ["content": "Hello"]])
        #expect(spec.root == "el-0")
        #expect(
            spec.elements["el-0"]
                == UIElement(type: "Text", props: ["content": "Hello"], children: []))
    }

    @Test("converts a tree with children (types.test.ts:960)")
    func children() {
        let spec = Spec.nestedToFlat([
            "type": "Card", "props": ["title": "Hello"],
            "children": [
                ["type": "Text", "props": ["content": "World"], "children": []],
                ["type": "Button", "props": ["label": "Click"]],
            ],
        ])
        #expect(spec.elements.count == 3)
        #expect(spec.elements["el-0"]?.children == ["el-1", "el-2"])
        #expect(spec.elements["el-1"]?.type == "Text")
        #expect(spec.elements["el-1"]?.children == [])
        #expect(spec.elements["el-2"]?.type == "Button")
        #expect(spec.elements["el-2"]?.children == [])
    }

    /// Upstream numbers slots in object key order (header before footer). Swift objects are
    /// unordered, so slots are numbered in sorted slot-name order: footer before header.
    @Test("converts nested named slots (types.test.ts:980; slot order sorted)")
    func slots() {
        let spec = Spec.nestedToFlat([
            "type": "Layout", "props": [:],
            "children": [["type": "Text", "props": ["content": "Main"]]],
            "slots": [
                "header": [["type": "Heading", "props": ["text": "Header"]]],
                "footer": [["type": "Button", "props": ["label": "Continue"]]],
            ],
        ])
        #expect(spec.elements.count == 4)
        #expect(spec.elements["el-0"]?.children == ["el-1"])
        #expect(spec.elements["el-0"]?.slots == ["footer": ["el-2"], "header": ["el-3"]])
        #expect(spec.elements["el-2"]?.type == "Button")
        #expect(spec.elements["el-3"]?.type == "Heading")
    }

    @Test("hoists state from root node (types.test.ts:1001)")
    func hoistsState() {
        let spec = Spec.nestedToFlat([
            "type": "Card", "props": ["title": "Hello"], "children": [],
            "state": ["count": 0, "items": []],
        ])
        #expect(spec.state == ["count": 0, "items": []])
        #expect(spec.elements["el-0"]?.jsonValue["state"] == nil)
    }

    @Test("preserves extra fields like visible and on (types.test.ts:1016)")
    func extraFields() {
        let spec = Spec.nestedToFlat([
            "type": "Panel", "props": [:], "visible": ["$state": "/showPanel"],
            "on": ["press": ["action": "setState", "params": ["statePath": "/x", "value": 1]]],
            "children": [],
        ])
        let element = spec.elements["el-0"]
        #expect(element?.visible?.jsonValue == ["$state": "/showPanel"])
        #expect(
            element?.on?["press"]
                == [ActionBinding(action: "setState", params: ["statePath": "/x", "value": 1])])
    }

    @Test("handles deeply nested trees (types.test.ts:1034)")
    func deep() {
        let spec = Spec.nestedToFlat([
            "type": "A", "props": [:],
            "children": [
                [
                    "type": "B", "props": [:],
                    "children": [
                        ["type": "C", "props": [:], "children": [["type": "D", "props": [:]]]]
                    ],
                ]
            ],
        ])
        #expect(spec.elements.count == 4)
        #expect(spec.elements["el-0"]?.children == ["el-1"])
        #expect(spec.elements["el-1"]?.children == ["el-2"])
        #expect(spec.elements["el-2"]?.children == ["el-3"])
        #expect(spec.elements["el-3"]?.children == [])
    }

    @Test("returns one element for an empty children array (types.test.ts:1060)")
    func emptyChildren() {
        let spec = Spec.nestedToFlat(["type": "Empty", "props": [:], "children": []])
        #expect(spec.elements.count == 1)
        #expect(spec.elements["el-0"]?.children == [])
    }

    @Test("does not hoist state from non-root nodes (types.test.ts:1071)")
    func noChildStateHoist() {
        let spec = Spec.nestedToFlat([
            "type": "Root", "props": [:],
            "children": [["type": "Child", "props": [:], "state": ["shouldNotHoist": true]]],
        ])
        #expect(spec.state == nil)
        #expect(spec.elements["el-1"]?.jsonValue["state"] == nil)
    }

    @Test("Non-node children are skipped and a missing type becomes unknown")
    func lenientNodes() {
        let spec = Spec.nestedToFlat([
            "props": [:], "children": ["text", 3, ["props": [:]], ["type": "T"]],
        ])
        #expect(spec.elements["el-0"]?.type == "unknown")
        #expect(spec.elements["el-0"]?.children == ["el-1"])
        #expect(spec.elements["el-1"]?.props == [:])
    }

    @Test("flatToTree: last parentless element is root; only four fields are carried")
    func flatToTree() {
        let rich = UIElement(
            type: "Card", props: ["t": 1], children: ["ignored"], slots: ["s": ["x"]],
            visible: .always(true), on: ["press": [ActionBinding(action: "a")]],
            repeat: RepeatConfig(statePath: .absolute("/rows")))
        let spec = Spec.flatToTree([
            FlatElement(key: "a", parentKey: nil, element: UIElement(type: "Old")),
            FlatElement(key: "card", parentKey: "", element: rich),
            FlatElement(key: "t1", parentKey: "card", element: UIElement(type: "Text")),
            FlatElement(key: "t2", parentKey: "card", element: UIElement(type: "Text")),
            FlatElement(key: "orphan", parentKey: "missing", element: UIElement(type: "Text")),
        ])
        #expect(spec.root == "card")
        #expect(spec.elements["card"]?.children == ["t1", "t2"])
        #expect(spec.elements["card"]?.visible == .always(true))
        #expect(spec.elements["card"]?.slots == nil)
        #expect(spec.elements["card"]?.on == nil)
        #expect(spec.elements["card"]?.repeat == nil)
        #expect(spec.elements["orphan"]?.children == [])
        #expect(spec.elements.count == 5)
    }
}
