import Testing

@testable import JSONRenderCore

@Suite("Spec composition")
struct SpecComposeTests {
    static let parent = Spec(
        root: "page",
        elements: [
            "page": UIElement(type: "Stack", children: ["title"], slots: ["footer": ["note"]]),
            "title": UIElement(type: "Heading", props: ["text": "Board"]),
            "note": UIElement(type: "Text"),
        ],
        state: ["theme": "dark"])

    static let child = Spec(
        root: "card",
        elements: [
            "card": UIElement(
                type: "Card", props: ["title": ["$template": "Hi ${/user/name} and ${name}"]],
                children: ["list", "input"],
                visible: VisibilityCondition(json: ["$state": "/show", "eq": ["$state": "/want"]])),
            "list": UIElement(
                type: "Stack", children: ["row"],
                repeat: RepeatConfig(statePath: .absolute("/rows"), key: "id")),
            "row": UIElement(
                type: "Checkbox",
                props: ["checked": ["$bindItem": "done"], "label": ["$item": "title"]],
                on: [
                    "change": [
                        ActionBinding(
                            action: "setState",
                            params: ["statePath": ["$item": "done"], "value": true],
                            onSuccess: .set(["/saved": true]))
                    ]
                ]),
            "input": UIElement(
                type: "Input", props: ["value": ["$bindState": "/form/name"]],
                on: [
                    "submit": [
                        ActionBinding(
                            action: "pushState",
                            params: [
                                "statePath": "/rows", "value": ["title": ["$state": "/form/name"]],
                                "clearStatePath": "/form/name",
                            ],
                            onError: .set(["/error": "$error.message"]))
                    ]
                ],
                watch: ["/form/name": [ActionBinding(action: "validateForm")]]),
        ],
        state: ["show": true, "rows": []])

    @Test("Ids are prefixed and the child root is appended to children")
    func idsAndChildren() throws {
        let spec = try Self.parent.composing(Self.child, into: "page", prefix: "w1")
        #expect(spec.elements["w1:card"] != nil)
        #expect(spec.elements["w1:card"]?.children == ["w1:list", "w1:input"])
        #expect(spec.elements["w1:list"]?.children == ["w1:row"])
        #expect(spec.elements["page"]?.children == ["title", "w1:card"])
        #expect(spec.elements.count == 3 + 4)
        #expect(spec.root == "page")
    }

    @Test("Slot append")
    func slotAppend() throws {
        let spec = try Self.parent.composing(Self.child, into: "page", slot: "footer", prefix: "w1")
        #expect(spec.elements["page"]?.slots?["footer"] == ["note", "w1:card"])
        #expect(spec.elements["page"]?.children == ["title"])
        let other = try Self.parent.composing(Self.child, into: "note", slot: "aside", prefix: "w2")
        #expect(other.elements["note"]?.slots == ["aside": ["w2:card"]])
    }

    @Test("State merges under the prefix and absolute paths move with it")
    func stateRewrite() throws {
        let spec = try Self.parent.composing(Self.child, into: "page", prefix: "w1")
        #expect(spec.state == ["theme": "dark", "w1": ["show": true, "rows": []]])
        let card = try #require(spec.elements["w1:card"])
        #expect(card.props["title"] == ["$template": "Hi ${/w1/user/name} and ${name}"])
        #expect(card.visible?.jsonValue == ["$state": "/w1/show", "eq": ["$state": "/w1/want"]])
        #expect(
            spec.elements["w1:list"]?.repeat
                == RepeatConfig(statePath: .absolute("/w1/rows"), key: "id"))
        let row = try #require(spec.elements["w1:row"])
        #expect(row.props["checked"] == ["$bindItem": "done"])
        #expect(row.props["label"] == ["$item": "title"])
        let rowBinding = try #require(row.on?["change"]?.first)
        #expect(rowBinding.params?["statePath"] == ["$item": "done"])
        #expect(rowBinding.onSuccess == .set(["/w1/saved": true]))
        let input = try #require(spec.elements["w1:input"])
        #expect(input.props["value"] == ["$bindState": "/w1/form/name"])
        let push = try #require(input.on?["submit"]?.first)
        #expect(push.params?["statePath"] == "/w1/rows")
        #expect(push.params?["clearStatePath"] == "/w1/form/name")
        #expect(push.params?["value"] == ["title": ["$state": "/w1/form/name"]])
        #expect(push.onError == .set(["/w1/error": "$error.message"]))
        #expect(input.watch?.keys.first == "/w1/form/name")
    }

    @Test("Conflicts and bad input throw")
    func conflicts() throws {
        #expect(throws: ComposeError.parentNotFound("nope")) {
            try Self.parent.composing(Self.child, into: "nope", prefix: "w1")
        }
        #expect(throws: ComposeError.invalidPrefix("a/b")) {
            try Self.parent.composing(Self.child, into: "page", prefix: "a/b")
        }
        #expect(throws: ComposeError.invalidPrefix("")) {
            try Self.parent.composing(Self.child, into: "page", prefix: "")
        }
        #expect(throws: ComposeError.invalidPrefix("__proto__")) {
            try Self.parent.composing(Self.child, into: "page", prefix: "__proto__")
        }
        let once = try Self.parent.composing(Self.child, into: "page", prefix: "w1")
        #expect(throws: ComposeError.idConflict("w1:card")) {
            try once.composing(Self.child, into: "page", prefix: "w1")
        }
        #expect(throws: ComposeError.stateConflict("theme")) {
            try Self.parent.composing(Self.child, into: "page", prefix: "theme")
        }
        var scalarState = Self.parent
        scalarState.state = 3
        #expect(throws: ComposeError.parentStateNotObject) {
            try scalarState.composing(Self.child, into: "page", prefix: "w1")
        }
    }

    @Test("A composed child still resolves through its own state")
    func resolvesAfterCompose() throws {
        let spec = try Self.parent.composing(Self.child, into: "page", prefix: "w1")
        var resolver = PropResolver(
            context: PropResolutionContext(state: spec.state ?? [:]))
        let card = try #require(spec.elements["w1:card"])
        #expect(
            VisibilityEvaluator.evaluate(card.visible, in: resolver.context.visibility) == false)
        #expect(resolver.resolveValue(["$state": "/w1/show"]) == true)
    }
}
