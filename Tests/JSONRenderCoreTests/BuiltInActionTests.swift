import Testing

@testable import JSONRenderCore

@Suite("Built-in actions")
struct BuiltInActionTests {
    static func run(
        _ binding: ActionBinding, state: JSONValue = [:],
        validation: (any FormValidationProvider)? = nil
    ) async throws -> JSONValue {
        let store = StateStore(initial: state)
        let dispatcher = ActionDispatcher(
            catalog: Catalog(), store: store, host: NoopActionHost(), validation: validation)
        try await dispatcher.dispatch(
            binding, elementID: "el",
            context: PropResolutionContext(state: await store.snapshot.state))
        return await store.snapshot.state
    }

    @Test("setState writes; an undefined value removes")
    func setState() async throws {
        #expect(
            try await Self.run(
                ActionBinding(action: "setState", params: ["statePath": "/a/b", "value": 3]))
                == ["a": ["b": 3]])
        #expect(
            try await Self.run(
                ActionBinding(
                    action: "setState", params: ["statePath": "/a", "value": ["$state": "/none"]]),
                state: ["a": 1]) == [:])
        #expect(
            try await Self.run(
                ActionBinding(action: "setState", params: ["statePath": "", "value": 1]),
                state: ["a": 1])
                == ["a": 1])
        #expect(
            try await Self.run(
                ActionBinding(
                    action: "setState", params: ["statePath": "/__proto__/x", "value": 1]))
                == [:])
    }

    @Test("pushState resolves $id, {$state} and clears clearStatePath")
    func pushState() async throws {
        let state = try await Self.run(
            ActionBinding(
                action: "pushState",
                params: [
                    "statePath": "/todos",
                    "value": [
                        "id": "$id", "key": ["$id": true], "title": ["$state": "/draft"],
                        "tags": ["$id"],
                    ],
                    "clearStatePath": "/draft",
                ]),
            state: ["todos": [["id": "old"]], "draft": "Buy milk"])
        let todos = try #require(state["todos"]?.arrayValue)
        #expect(todos.count == 2)
        let added = todos[1]
        #expect(added["title"] == "Buy milk")
        #expect(added["id"]?.stringValue?.count == 36)
        #expect(added["key"]?.stringValue?.count == 36)
        #expect(added["id"] != added["key"])
        #expect(added["tags"]?[0]?.stringValue?.count == 36)
        #expect(state["draft"] == "")
    }

    @Test("pushState onto a missing path starts an array; deepResolve drops missing refs")
    func pushStateMissing() async throws {
        let state = try await Self.run(
            ActionBinding(action: "pushState", params: ["statePath": "/list", "value": ["x": 1]]))
        #expect(state == ["list": [["x": 1]]])
        var counter = 0
        let resolved = BuiltInAction.deepResolve(
            [
                "a": ["$state": "/none"], "b": [["$state": "/none"]],
                "c": ["$state": "/n", "extra": 1],
            ],
            state: ["n": 5],
            makeID: {
                counter += 1
                return "id\(counter)"
            })
        #expect(resolved == ["b": [.null], "c": ["$state": "/n", "extra": 1]])
    }

    @Test("removeState removes by index")
    func removeState() async throws {
        #expect(
            try await Self.run(
                ActionBinding(action: "removeState", params: ["statePath": "/l", "index": 1]),
                state: ["l": ["a", "b", "c"]]) == ["l": ["a", "c"]])
        #expect(
            try await Self.run(
                ActionBinding(action: "removeState", params: ["statePath": "/l", "index": 9]),
                state: ["l": ["a"]]) == ["l": ["a"]])
        #expect(
            try await Self.run(
                ActionBinding(action: "removeState", params: ["statePath": "/l", "index": "0"]),
                state: ["l": ["a"]]) == ["l": ["a"]])
    }

    @Test("validateForm writes { valid, errors } to /formValidation by default")
    func validateForm() async throws {
        let validation = FixedValidation(
            outcome: FormValidationOutcome(valid: false, errors: ["/form/email": ["Required"]]))
        #expect(
            try await Self.run(ActionBinding(action: "validateForm"), validation: validation)
                == ["formValidation": ["valid": false, "errors": ["/form/email": ["Required"]]]])
        #expect(
            try await Self.run(
                ActionBinding(action: "validateForm", params: ["statePath": "/result"]),
                validation: FixedValidation(outcome: FormValidationOutcome(valid: true)))
                == ["result": ["valid": true, "errors": [:]]])
        #expect(
            try await Self.run(
                ActionBinding(action: "validateForm", params: ["statePath": ""]),
                validation: validation)["formValidation"]?["valid"]
                == false)
    }

    @Test("validateForm without a provider does nothing")
    func validateFormUnavailable() async throws {
        #expect(try await Self.run(ActionBinding(action: "validateForm")) == [:])
    }

    @Test(
        "toggleState (extension)",
        arguments: [
            (JSONValue?.none, JSONValue.bool(true)), (.null, .bool(true)),
            (.bool(true), .bool(false)),
            (.bool(false), .bool(true)), (.string("x"), .bool(false)), (.string(""), .bool(true)),
            (.number(0), .bool(true)),
        ])
    func toggleState(_ current: JSONValue?, _ expected: JSONValue) async throws {
        var state: JSONValue = [:]
        if let current { state = ["flag": current] }
        let result = try await Self.run(
            ActionBinding(action: "toggleState", params: ["statePath": "/flag"]), state: state)
        #expect(result["flag"] == expected)
    }

    @Test("incrementState (extension): default 1, custom by, non-number counts as 0")
    func incrementState() async throws {
        #expect(
            try await Self.run(
                ActionBinding(action: "incrementState", params: ["statePath": "/n"]),
                state: ["n": 2]) == ["n": 3])
        #expect(
            try await Self.run(
                ActionBinding(action: "incrementState", params: ["statePath": "/n", "by": -5]),
                state: ["n": 2]) == ["n": -3])
        #expect(
            try await Self.run(
                ActionBinding(action: "incrementState", params: ["statePath": "/n", "by": 2.5]),
                state: ["n": "x"]) == ["n": 2.5])
        #expect(
            try await Self.run(ActionBinding(action: "incrementState", params: ["statePath": "/n"]))
                == ["n": 1])
    }

    @Test("Built-ins shadow catalog actions with the same name, as upstream")
    func builtInsWin() async throws {
        let store = StateStore()
        var catalog = Catalog()
        catalog.action("setState") { _, _ in throw ActionFailure("never") }
        let dispatcher = ActionDispatcher(catalog: catalog, store: store, host: NoopActionHost())
        try await dispatcher.dispatch(
            ActionBinding(action: "setState", params: ["statePath": "/a", "value": 1]),
            elementID: nil, context: PropResolutionContext(state: [:]))
        #expect(await store.get("/a") == 1)
        #expect(
            BuiltInAction.upstream.map(\.rawValue) == [
                "setState", "pushState", "removeState", "validateForm",
            ])
        let extensionsFlagged = BuiltInAction.extensions.allSatisfy { $0.isExtension }
        #expect(extensionsFlagged)
        #expect(BuiltInAction(rawValue: "push") == nil)
        #expect(BuiltInAction(rawValue: "pop") == nil)
    }
}
