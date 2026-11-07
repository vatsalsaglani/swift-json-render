import Testing

@testable import JSONRenderCore

@Suite("ActionDispatcher flow")
struct DispatcherFlowTests {
    struct Setup {
        let store: StateStore
        let host: RecordingHost
        let log: CallLog
        let dispatcher: ActionDispatcher
        let events: AsyncStream<StreamObserver.Event>
        let observer: StreamObserver

        init(
            state: JSONValue = [:], confirm: Bool = true,
            configure: (inout Catalog, CallLog) -> Void
        ) {
            let log = CallLog()
            var catalog = Catalog()
            configure(&catalog, log)
            store = StateStore(initial: state)
            host = RecordingHost(answer: confirm, log: log)
            let (observer, events) = StreamObserver.make()
            self.observer = observer
            self.events = events
            self.log = log
            dispatcher = ActionDispatcher(
                catalog: catalog, store: store, host: host, observer: observer)
        }

        @discardableResult
        func dispatch(_ binding: ActionBinding, elementID: String? = "el") async throws
            -> ActionSettleInfo.Outcome
        {
            try await dispatcher.dispatch(
                binding, elementID: elementID,
                context: PropResolutionContext(state: await store.snapshot.state))
        }

        func observed() async -> [StreamObserver.Event] {
            observer.continuation.finish()
            var all: [StreamObserver.Event] = []
            for await event in events { all.append(event) }
            return all
        }
    }

    static let confirm = ActionConfirm(title: "Delete ${/name}?", message: "Remove ${/name} now")

    @Test("A declined confirm stops the handler and does not throw")
    func confirmDeclined() async throws {
        let setup = Setup(state: ["name": "Ada"], confirm: false) { catalog, log in
            catalog.action("delete") { _, _ in
                await log.append("handler", [])
                return nil
            }
        }
        let outcome = try await setup.dispatch(
            ActionBinding(action: "delete", confirm: Self.confirm))
        #expect(outcome == .cancelled)
        #expect(await setup.log.calls.isEmpty)
        let confirmations = await setup.host.confirmations
        #expect(confirmations.count == 1)
        #expect(confirmations.first?.title == "Delete Ada?")
        #expect(confirmations.first?.message == "Remove Ada now")
        let events = await setup.observed()
        guard case .settled(let settle)? = events.last else {
            Issue.record("No settle event")
            return
        }
        #expect(settle.outcome == .cancelled)
        #expect(!settle.ok)
    }

    @Test("Documented deviation: built-ins honour confirm")
    func builtInConfirm() async throws {
        let declined = Setup(confirm: false) { _, _ in }
        try await declined.dispatch(
            ActionBinding(
                action: "setState", params: ["statePath": "/a", "value": 1], confirm: Self.confirm))
        #expect(await declined.store.get("/a") == nil)
        #expect(await declined.host.confirmations.count == 1)

        let accepted = Setup(confirm: true) { _, _ in }
        try await accepted.dispatch(
            ActionBinding(
                action: "setState", params: ["statePath": "/a", "value": 1], confirm: Self.confirm))
        #expect(await accepted.store.get("/a") == 1)
    }

    @Test("A missing handler does nothing and asks for no confirmation")
    func missingHandler() async throws {
        let setup = Setup { _, _ in }
        let outcome = try await setup.dispatch(
            ActionBinding(action: "unknown", confirm: Self.confirm))
        #expect(outcome == .noHandler)
        #expect(await setup.host.confirmations.isEmpty)
        let events = await setup.observed()
        guard case .settled(let settle)? = events.last else {
            Issue.record("No settle event")
            return
        }
        #expect(settle.outcome == .noHandler)
        #expect(!settle.ok)  // upstream warns
    }

    @Test("onSuccess navigate, set and action")
    func onSuccess() async throws {
        let setup = Setup(state: ["n": 4]) { catalog, log in
            catalog.action("save") { params, _ in
                await log.append("save", [.object(params.defined)])
                return nil
            }
            catalog.action("toast") { params, _ in
                await log.append("toast", [.object(params.defined)])
                return nil
            }
        }
        let completed = try await setup.dispatch(
            ActionBinding(action: "save", onSuccess: .navigate("/done")))
        #expect(completed == .completed)
        #expect(try await setup.dispatch(ActionBinding(action: "validateForm")) == .unavailable)
        #expect(await setup.host.navigations == ["/done"])
        try await setup.dispatch(
            ActionBinding(action: "save", onSuccess: .set(["/saved": true, "/count": 2])))
        #expect(await setup.store.get("/saved") == true)
        #expect(await setup.store.get("/count") == 2)
        try await setup.dispatch(
            ActionBinding(
                action: "save", params: ["v": ["$state": "/n"]],
                onSuccess: .action("toast", params: ["n": ["$state": "/n"]])))
        let calls = await setup.log.calls.map(\.fn)
        #expect(calls == ["save", "navigate", "save", "save", "toast"])
        #expect(await setup.log.calls.last?.args == [["n": 4]])
    }

    @Test("onError set replaces $error.message; onError action runs; no onError rethrows")
    func onError() async throws {
        let setup = Setup { catalog, log in
            catalog.action("save") { _, _ in throw ActionFailure("Disk full") }
            catalog.action("report") { _, _ in
                await log.append("report", [])
                return nil
            }
        }
        try await setup.dispatch(
            ActionBinding(
                action: "save", onError: .set(["/error": "$error.message", "/failed": true])))
        #expect(await setup.store.get("/error") == "Disk full")
        #expect(await setup.store.get("/failed") == true)
        try await setup.dispatch(
            ActionBinding(action: "save", onError: .action("report", params: nil)))
        #expect(await setup.log.calls.map(\.fn) == ["report"])
        await #expect(throws: ActionFailure("Disk full")) {
            try await setup.dispatch(ActionBinding(action: "save"))
        }
    }

    @Test("An error thrown by onSuccess runs onError, as upstream")
    func onSuccessErrorRunsOnError() async throws {
        let setup = Setup { catalog, _ in
            catalog.action("save") { _, _ in nil }
            catalog.action("explode") { _, _ in throw ActionFailure("follow-up failed") }
        }
        try await setup.dispatch(
            ActionBinding(
                action: "save", onSuccess: .action("explode", params: nil),
                onError: .set(["/error": "$error.message"])))
        #expect(await setup.store.get("/error") == "follow-up failed")
    }

    @Test("The observer gets dispatched and settled with ids and names, never params")
    func observer() async throws {
        let setup = Setup { catalog, _ in
            catalog.action("save") { _, _ in nil }
            catalog.action("fail") { _, _ in throw ActionFailure("x") }
        }
        try await setup.dispatch(
            ActionBinding(action: "save", params: ["secret": "hunter2"]), elementID: "button-1")
        _ = try? await setup.dispatch(ActionBinding(action: "fail"))
        let events = await setup.observed()
        #expect(events.count == 4)
        guard case .dispatched(let first) = events[0], case .settled(let firstSettle) = events[1],
            case .dispatched(let second) = events[2], case .settled(let secondSettle) = events[3]
        else {
            Issue.record("Unexpected event order")
            return
        }
        #expect(first.name == "save")
        #expect(first.elementID == "button-1")
        #expect(firstSettle.id == first.id)
        #expect(firstSettle.ok)
        #expect(firstSettle.outcome == .completed)
        #expect(firstSettle.duration >= .zero)
        #expect(second.name == "fail")
        #expect(secondSettle.id == second.id)
        #expect(!secondSettle.ok)
        #expect(secondSettle.outcome == .failed)
        #expect(first.id != second.id)
        #expect(!String(describing: events).contains("hunter2"))
    }

    @Test("Handlers receive resolved params, with undefined kept as nil")
    func handlerParams() async throws {
        let setup = Setup(state: ["a": 1]) { catalog, log in
            catalog.action("probe") { params, _ in
                await log.append(
                    "probe",
                    [.array(params.keys.sorted().map { .string($0) }), .object(params.defined)])
                return nil
            }
        }
        try await setup.dispatch(
            ActionBinding(
                action: "probe", params: ["a": ["$state": "/a"], "gone": ["$state": "/none"]]))
        #expect(await setup.log.calls.first?.args == [["a", "gone"], ["a": 1]])
    }

    @Test("A catalog action without a handler is declared only")
    func declaredOnly() async throws {
        let setup = Setup { catalog, _ in
            catalog.action(
                "open_file", params: .object([.init(name: "path", schema: .string)]),
                description: "Open a file")
        }
        try await setup.dispatch(ActionBinding(action: "open_file"))
        #expect(setup.dispatcher.catalog.actionOrder == ["open_file"])
        #expect(setup.dispatcher.catalog.actions["open_file"]?.description == "Open a file")
    }
}

@Suite("Repeat scope actions")
struct RepeatScopeActionTests {
    @Test("$item params give the absolute path at the emitting scope, also in nested repeats")
    func nestedRepeat() async throws {
        let state: JSONValue = [
            "groups": [
                ["name": "A", "items": [["done": false], ["done": false]]],
                ["name": "B", "items": [["done": false]]],
            ]
        ]
        let store = StateStore(initial: state)
        let dispatcher = ActionDispatcher(catalog: Catalog(), store: store, host: NoopActionHost())

        // Outer repeat over /groups, row 0.
        let outerPath = RepeatScope.resolveStatePath(.absolute("/groups"), enclosing: nil)
        let outer = RepeatScope(
            item: state["groups"]?[0] ?? .null, index: 0,
            basePath: RepeatScope.itemStatePath(try #require(outerPath), index: 0))
        // Inner repeat over { "$item": "items" }, row 1.
        let innerPath = try #require(
            RepeatScope.resolveStatePath(.item("items"), enclosing: outer.basePath))
        #expect(innerPath.description == "/groups/0/items")
        let inner = RepeatScope(
            item: state["groups"]?[0]?["items"]?[1] ?? .null, index: 1,
            basePath: RepeatScope.itemStatePath(innerPath, index: 1))

        let binding = ActionBinding(
            action: "setState",
            params: ["statePath": ["$item": "done"], "value": true, "row": ["$index": true]])
        let context = PropResolutionContext(state: await store.snapshot.state, scope: inner)
        let (resolved, warnings) = binding.resolved(in: context)
        #expect(warnings.isEmpty)
        #expect(resolved.params["statePath"] == .some("/groups/0/items/1/done"))
        #expect(resolved.params["row"] == .some(1))

        try await dispatcher.dispatch(binding, elementID: "check", context: context)
        #expect(await store.get("/groups/0/items/1/done") == true)
        #expect(await store.get("/groups/0/items/0/done") == false)
        #expect(await store.get("/groups/1/items/0/done") == false)
    }

    @Test("$item outside a repeat resolves to undefined and the built-in does nothing")
    func outsideScope() async throws {
        let store = StateStore(initial: ["a": 1])
        let dispatcher = ActionDispatcher(catalog: Catalog(), store: store, host: NoopActionHost())
        let binding = ActionBinding(
            action: "setState", params: ["statePath": ["$item": "x"], "value": 2])
        let (resolved, warnings) = binding.resolved(in: PropResolutionContext(state: ["a": 1]))
        #expect(resolved.params["statePath"] == .some(JSONValue?.none))
        #expect(warnings == [.bindItemOutsideScope("x")])
        try await dispatcher.dispatch(
            binding, elementID: nil, context: PropResolutionContext(state: ["a": 1]))
        #expect(await store.snapshot.state == ["a": 1])
    }

    @Test("Repeat state paths: empty and slash give the enclosing row; absolute paths pass")
    func statePaths() {
        let enclosing: JSONPointer = "/groups/2"
        #expect(RepeatScope.resolveStatePath(.item(""), enclosing: enclosing) == enclosing)
        #expect(RepeatScope.resolveStatePath(.item("/"), enclosing: enclosing) == enclosing)
        #expect(RepeatScope.resolveStatePath(.item("sub"), enclosing: nil) == nil)
        #expect(RepeatScope.resolveStatePath(.absolute("/x"), enclosing: enclosing) == "/x")
        #expect(RepeatScope.resolveStatePath(.absolute("/__proto__"), enclosing: nil) == nil)
    }
}
