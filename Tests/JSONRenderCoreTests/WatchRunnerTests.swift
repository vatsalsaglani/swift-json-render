import Testing

@testable import JSONRenderCore

@Suite("WatchRunner")
struct WatchRunnerTests {
    /// A store, a dispatcher whose catalog actions report into `events`, and a runner.
    struct Harness {
        let store: StateStore
        let runner: WatchRunner
        let events: AsyncStream<String>
        let sink: AsyncStream<String>.Continuation

        init(state: JSONValue, gate: AsyncStream<Void>? = nil) {
            let (events, sink) = AsyncStream.makeStream(of: String.self)
            var catalog = Catalog()
            catalog.action("log") { params, _ in
                sink.yield((params["tag"] ?? nil)?.jsString ?? "undefined")
                return nil
            }
            catalog.action("block") { _, _ in
                sink.yield("started")
                if let gate {
                    for await _ in gate {}
                }
                return nil
            }
            catalog.action("fail") { _, _ in throw ActionFailure("boom") }
            store = StateStore(initial: state)
            runner = WatchRunner(
                store: store,
                dispatcher: ActionDispatcher(catalog: catalog, store: store, host: NoopActionHost())
            )
            self.events = events
            self.sink = sink
        }

        func start(_ watch: [String: [ActionBinding]]) async -> Task<Void, Never> {
            let subscription = await store.subscribe(bufferingPolicy: .unbounded)
            let runner = runner
            return Task {
                await runner.run(
                    elementID: "el", watch: watch, subscription: subscription,
                    context: { PropResolutionContext(state: $0.state) })
            }
        }
    }

    static func log(_ tag: JSONValue) -> ActionBinding {
        ActionBinding(action: "log", params: ["tag": tag])
    }

    @Test("The baseline does not fire; only the changed path fires")
    func onlyChangedPath() async {
        let harness = Harness(state: ["a": 1, "b": 1])
        let task = await harness.start(["/a": [Self.log("a")], "/b": [Self.log("b")]])
        var events = harness.events.makeAsyncIterator()
        await harness.store.set("/b", 2)
        #expect(await events.next() == "b")
        await harness.store.set("/z", 9)  // not watched
        await harness.store.set("/a", 2)
        #expect(await events.next() == "a")
        task.cancel()
        await task.value
    }

    @Test("Bindings run in order and resolve params against live state")
    func sequentialLiveParams() async {
        let harness = Harness(state: ["a": 1])
        let task = await harness.start([
            "/a": [
                ActionBinding(
                    action: "setState", params: ["statePath": "/copy", "value": ["$state": "/a"]]),
                Self.log(["$state": "/copy"]),
                Self.log("second"),
            ]
        ])
        var events = harness.events.makeAsyncIterator()
        await harness.store.set("/a", 7)
        #expect(await events.next() == "7")
        #expect(await events.next() == "second")
        task.cancel()
        await task.value
    }

    @Test("undefined → null is a change")
    func undefinedToNull() async {
        let harness = Harness(state: [:])
        let task = await harness.start(["/v": [Self.log("v")]])
        var events = harness.events.makeAsyncIterator()
        await harness.store.set("/v", .null)
        #expect(await events.next() == "v")
        task.cancel()
        await task.value
    }

    @Test("A throwing binding stops the round")
    func throwStopsRound() async {
        let harness = Harness(state: ["a": 1, "b": 1])
        let task = await harness.start([
            "/a": [ActionBinding(action: "fail"), Self.log("after-fail")],
            "/b": [Self.log("b")],
        ])
        var events = harness.events.makeAsyncIterator()
        await harness.store.update([("/a", 2), ("/b", 2)])
        await harness.store.set("/b", 3)
        // The first round stops at "fail" (so "b" of round one never runs); round two runs "b".
        #expect(await events.next() == "b")
        task.cancel()
        await task.value
        harness.sink.finish()
        #expect(await events.next() == nil)
    }

    @Test("Cancellation stops after the running binding")
    func cancellation() async {
        let (gate, gateSink) = AsyncStream.makeStream(of: Void.self)
        let harness = Harness(state: ["a": 1], gate: gate)
        let task = await harness.start(["/a": [ActionBinding(action: "block"), Self.log("after")]])
        var events = harness.events.makeAsyncIterator()
        await harness.store.set("/a", 2)
        #expect(await events.next() == "started")
        task.cancel()
        await task.value
        gateSink.finish()
        harness.sink.finish()
        #expect(await events.next() == nil)
    }
}
