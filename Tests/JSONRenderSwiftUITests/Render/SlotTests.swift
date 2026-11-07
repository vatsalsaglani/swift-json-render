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
            JRSlots.vocabulary == ["header", "footer", "leading", "trailing", "empty", "loading", "error"])
    }
}
