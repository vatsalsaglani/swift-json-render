import Testing

@testable import JSONRenderCore

@Suite("StateStore")
struct StateStoreTests {
    @Test("Initial state: nil and non-objects become {}")
    func initialState() async {
        #expect(await StateStore().snapshot.state == [:])
        #expect(await StateStore(initial: 3).snapshot.state == [:])
        #expect(await StateStore(initial: ["a": 1]).snapshot.state == ["a": 1])
        #expect(await StateStore().snapshot.version == 0)
    }

    @Test("A no-op set emits nothing")
    func noOpSet() async {
        let store = StateStore(initial: ["a": 1, "o": ["x": [1, 2]]])
        let subscription = await store.subscribe(bufferingPolicy: .unbounded)
        await store.set("/a", 1)
        await store.set("/o", ["x": [1, 2]])  // equal value (upstream would notify: new reference)
        await store.remove("/missing")
        await store.set("/a", 2)
        var updates = subscription.updates.makeAsyncIterator()
        let first = await updates.next()
        #expect(first?.version == 1)
        #expect(first?.state["a"] == 2)
        #expect(first?.changed == ["/a"])
    }

    @Test("update() is one commit with one snapshot")
    func updateIsOneCommit() async {
        let store = StateStore()
        let subscription = await store.subscribe(bufferingPolicy: .unbounded)
        let changed = await store.update([("/a", 1), ("/b/c", true), ("/a", 1)])
        #expect(changed)
        await store.set("/z", "after")
        var updates = subscription.updates.makeAsyncIterator()
        let first = await updates.next()
        #expect(first?.version == 1)
        #expect(first?.state == ["a": 1, "b": ["c": true]])
        #expect(first?.changed == ["/a", "/b/c"])
        let second = await updates.next()
        #expect(second?.version == 2)
        #expect(await store.update([("/a", 1)]) == false)
    }

    @Test("Refused writes commit nothing")
    func refused() async {
        let store = StateStore(initial: ["list": [1]])
        #expect(
            await store.update([("/list/5/x", 1), (JSONPointer.root, 2), ("/__proto__/x", 1)])
                == false)
        #expect(await store.snapshot.state == ["list": [1]])
        #expect(await store.snapshot.version == 0)
    }

    @Test("Two subscribers both receive each commit")
    func twoSubscribers() async {
        let store = StateStore()
        let first = await store.snapshots(bufferingPolicy: .unbounded)
        let second = await store.snapshots(bufferingPolicy: .unbounded)
        await store.set("/n", 1)
        var a = first.makeAsyncIterator()
        var b = second.makeAsyncIterator()
        #expect(await a.next()?.version == 0)
        #expect(await b.next()?.version == 0)
        #expect(await a.next()?.state == ["n": 1])
        #expect(await b.next()?.state == ["n": 1])
        #expect(await store.subscriberCount == 2)
    }

    @Test("A stream ends when the store is released")
    func endsOnRelease() async {
        var store: StateStore? = StateStore(initial: ["a": 1])
        let stream = await store!.snapshots(bufferingPolicy: .unbounded)
        var iterator = stream.makeAsyncIterator()
        #expect(await iterator.next()?.version == 0)
        store = nil
        #expect(await iterator.next() == nil)
    }

    @Test("bufferingNewest(1) gives a slow reader only the newest snapshot")
    func newestOnly() async {
        let store = StateStore()
        let stream = await store.snapshots()
        for value in 1...5 { await store.set("/n", .number(Double(value))) }
        var iterator = stream.makeAsyncIterator()
        let latest = await iterator.next()
        #expect(latest?.version == 5)
        #expect(latest?.state["n"] == 5)
    }

    @Test("replaceAll commits the root pointer; equal state is a no-op")
    func replaceAll() async {
        let store = StateStore(initial: ["a": 1])
        await store.replaceAll(["a": 1])
        #expect(await store.snapshot.version == 0)
        await store.replaceAll(["b": 2])
        #expect(await store.snapshot.state == ["b": 2])
        #expect(await store.snapshot.changed == [JSONPointer.root])
        await store.replaceAll("not an object")
        #expect(await store.snapshot.state == [:])
    }

    @Test("get and remove follow the path operations")
    func getRemove() async {
        let store = StateStore(initial: ["list": [1, 2, 3]])
        #expect(await store.get("/list/1") == 2)
        await store.remove("/list/0")
        #expect(await store.get("/list") == [2, 3])
    }
}
