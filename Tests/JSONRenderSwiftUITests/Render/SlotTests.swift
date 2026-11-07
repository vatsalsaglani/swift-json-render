import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import Testing

@Suite struct SlotTests {
    @Test func defaultSlotWarnsAndActsAsChildren() throws {
        let spec = Spec(
            root: "card",
            elements: [
                "card": UIElement(type: "Card", children: ["a"], slots: ["default": ["b"]]),
                "a": UIElement(type: "Text", props: ["text": "a"]),
                "b": UIElement(type: "Text", props: ["text": "b"]),
            ])
        let plan = RenderPlan(spec: spec)
        let node = try #require(plan.nodes["card"])
        #expect(ElementResolution.childIDs(of: node) == ["a", "b"])
        #expect(ElementResolution.namedSlots(of: node).isEmpty)
        let walk = RenderWalk(spec: spec, plan: plan, state: [:], catalog: try .standard)
        #expect(walk.warnings == [.defaultSlot(id: "card", type: "Card")])
    }

    @Test func unknownSlotWarnsOncePerElement() throws {
        let warnings = ElementResolution.slotWarnings(
            id: "card", type: "Card", slots: ["footer": ["x"], "sidebar": ["y"]],
            declared: ["default", "header", "footer"])
        #expect(warnings == [.unknownSlot(id: "card", type: "Card", slot: "sidebar")])
    }

    @Test func footerKeepsItsOrder() throws {
        let spec = Spec(
            root: "card",
            elements: [
                "card": UIElement(type: "Card", slots: ["footer": ["c", "a", "b"]]),
                "a": UIElement(type: "Text", props: ["text": "a"]),
                "b": UIElement(type: "Text", props: ["text": "b"]),
                "c": UIElement(type: "Text", props: ["text": "c"]),
            ])
        let plan = RenderPlan(spec: spec)
        let node = try #require(plan.nodes["card"])
        #expect(ElementResolution.namedSlots(of: node)["footer"] == ["c", "a", "b"])
        let context = JRRenderContext(
            id: "card", slots: ["footer": JRChildren(ids: ["c", "a", "b"]), "header": .empty])
        #expect(context.slot("footer")?.ids == ["c", "a", "b"])
        #expect(context.slot("header") == nil)
        let walk = RenderWalk(spec: spec, plan: plan, state: [:], catalog: try .standard)
        #expect(walk.elements.map(\.id) == ["card", "c", "a", "b"])
        #expect(walk.warnings.isEmpty)
    }

    @Test func vocabularyIsFixed() {
        #expect(
            JRSlots.vocabulary == [
                "header", "footer", "leading", "trailing", "empty", "loading", "error",
            ])
    }
}

@Suite struct AccessibilityAuditTests {
    @Test func labelsComeFromSpecPropsAndControlsNeedOne() throws {
        let spec = Spec(
            root: "s",
            elements: [
                "s": UIElement(type: "Stack", children: ["h", "tabs", "pop", "bare"]),
                "h": UIElement(type: "Heading", props: ["text": "Status"]),
                "tabs": UIElement(
                    type: "Tabs", props: ["tabs": [], "value": ["$bindState": "/t"]]),
                "pop": UIElement(type: "Popover", props: ["trigger": "More", "content": "x"]),
                "bare": UIElement(type: "Text", props: ["text": "  "]),
            ])
        let walk = RenderWalk(
            spec: spec, plan: RenderPlan(spec: spec), state: [:], catalog: try .standard)
        let entries = AccessibilityAudit.entries(in: walk)
        #expect(entries.map(\.id) == ["s", "h", "tabs", "pop", "bare"])
        #expect(entries[1].label == "Status" && !entries[1].isControl)
        #expect(entries[2].isMissingLabel)
        #expect(entries[3].label == "More" && entries[3].isControl && !entries[3].isMissingLabel)
        #expect(entries[4].label == nil && !entries[4].isMissingLabel)
    }
}
