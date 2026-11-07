import Testing

@testable import JSONRenderCore

@Suite("Lenient spec projection")
struct LenientSpecTests {
    @Test("An element without a type is skipped with a reason")
    func noType() {
        let (spec, skipped) = Spec.lenient([
            "root": "main",
            "elements": [
                "main": ["type": "Card", "children": ["a", "b", "c"]],
                "a": ["props": [:]],
                "b": "not an element",
                "c": ["type": "Text", "props": 3],
            ],
        ])
        #expect(spec.root == "main")
        #expect(Set(spec.elements.keys) == ["main"])
        #expect(skipped == ["a": "no type", "b": "not an object", "c": "invalid field"])
        #expect(RenderPlan(spec: spec).dangling == ["a", "b", "c"])
    }

    @Test("A single on binding is normalised")
    func singleBinding() throws {
        let (spec, _) = Spec.lenient([
            "elements": [
                "b": ["type": "Button", "on": ["press": ["action": "go"]]],
                "x": ["props": [:]],
            ]
        ])
        let element = try #require(spec.elements["b"])
        #expect(element.on?["press"]?.count == 1)
    }

    @Test("Unknown element keys are ignored")
    func unknownKey() {
        let (spec, skipped) = Spec.lenient([
            "elements": ["a": ["type": "Text", "sparkle": true]], "root": 3,
        ])
        #expect(spec.elements["a"]?.type == "Text")
        #expect(skipped.isEmpty)
        #expect(spec.root == "")
    }

    @Test("A document that is not an object is an empty spec")
    func notAnObject() {
        for document: JSONValue in [nil, 3, "x", [1, 2]] {
            let (spec, skipped) = Spec.lenient(document)
            #expect(spec == Spec(root: "", elements: [:]))
            #expect(skipped.isEmpty)
        }
    }

    @Test("Non-object state is dropped")
    func state() {
        #expect(Spec.lenient(["state": [1], "elements": ["a": [:]]]).spec.state == nil)
        #expect(Spec.lenient(["state": ["n": 1], "elements": ["a": [:]]]).spec.state == ["n": 1])
    }
}
