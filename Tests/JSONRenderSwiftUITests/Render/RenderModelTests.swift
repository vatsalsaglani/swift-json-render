import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog
import JSONRenderSwiftUI
import Testing

@MainActor
@Suite struct RenderModelTests {
    private func decode(_ json: String) throws -> Spec {
        try Spec.decode(Data(json.utf8)).spec
    }

    @Test func followsEveryStoreCommit() async throws {
        let spec = try decode(
            #"{"root":"t","state":{"n":0},"elements":{"t":{"type":"Text","props":{"text":"x"}}}}"#)
        let store = StateStore(initial: spec.state)
        let model = RenderModel(spec: spec, catalog: try .standard, store: store)
        let runner = Task { await model.run() }
        defer { runner.cancel() }
        for value in 1...5 {
            await store.set("/n", .number(Double(value)))
            await waitUntil { model.stateSnapshot.version == UInt64(value) }
            #expect(model.stateSnapshot.state["n"] == .number(Double(value)))
            #expect(model.stateSnapshot.changed == ["/n"])
        }
    }

    @Test func boundWritesAreImmediateOrderedAndOneCommitEach() async throws {
        let spec = try decode(
            #"{"root":"t","state":{"q":""},"elements":{"t":{"type":"Text","props":{"text":{"$state":"/q"}}}}}"#
        )
        let store = StateStore(initial: spec.state)
        let model = RenderModel(spec: spec, catalog: try .standard, store: store)
        var typed = ""
        for character in "keystrokes" {
            typed.append(character)
            model.write("/q", .string(typed))
            #expect(model.stateSnapshot.state["q"] == .string(typed))
        }
        model.write("/q", .string(typed))  // equal value: no-op
        await model.flushWrites()
        let snapshot = await store.snapshot
        #expect(snapshot.version == 10)
        #expect(snapshot.state["q"] == "keystrokes")
    }

    @Test func emitDispatchesBindingsInOrderThroughTheObserver() async throws {
        let spec = try decode(
            #"""
            {"root":"b","state":{"a":0},"elements":{"b":{"type":"Text","props":{"text":"go"},
              "on":{"press":[{"action":"setState","params":{"statePath":"/a","value":1}},
                             {"action":"setState","params":{"statePath":"/b","value":{"$state":"/a"}}}]}}}}
            """#)
        let observer = RecordingObserver()
        let store = StateStore(initial: spec.state)
        let model = RenderModel(
            spec: spec, catalog: try .standard, store: store, observer: observer)
        await model.emit(id: "b", event: "press").value
        let state = await store.snapshot.state
        #expect(state["a"] == 1)
        #expect(state["b"] == 1)
        #expect(
            observer.entries == [
                "b:setState", "b:setState:completed", "b:setState", "b:setState:completed",
            ])
        await model.emit(id: "b", event: "unbound").value
        #expect(observer.entries.count == 4)
    }

    @Test func declinedConfirmStopsTheRemainingBindings() async throws {
        let spec = try decode(
            #"""
            {"root":"b","elements":{"b":{"type":"Text","props":{"text":"go"},
              "on":{"press":[{"action":"setState","params":{"statePath":"/a","value":1},
                              "confirm":{"title":"Sure?","message":"Really"}},
                             {"action":"setState","params":{"statePath":"/b","value":2}}]}}}}
            """#)
        let observer = RecordingObserver()
        let store = StateStore()
        let model = RenderModel(
            spec: spec, catalog: try .standard, store: store, host: DecliningHost(),
            observer: observer)
        await model.emit(id: "b", event: "press").value
        let state = await store.snapshot.state
        #expect(state["a"] == nil && state["b"] == nil)
        #expect(observer.entries == ["b:setState", "b:setState:cancelled"])
    }

    @Test func emitUsesTheRowScope() async throws {
        let spec = try decode(
            #"""
            {"root":"list","state":{"todos":[{"t":"a"},{"t":"b"}]},"elements":{
              "list":{"type":"Stack","repeat":{"statePath":"/todos"},"children":["x"]},
              "x":{"type":"Text","props":{"text":{"$item":"t"}},
                "on":{"press":{"action":"removeState","params":{"statePath":"/todos","index":{"$index":true}}}}}}}
            """#)
        let store = StateStore(initial: spec.state)
        let model = RenderModel(spec: spec, catalog: try .standard, store: store)
        let row = RepeatScope(item: ["t": "b"], index: 1, basePath: "/todos/1")
        await model.emit(id: "x", event: "press", scope: row).value
        #expect(await store.snapshot.state["todos"] == [["t": "a"]])
    }

    @Test func watchersFireOnChangeOnly() async throws {
        let spec = try decode(
            #"""
            {"root":"w","state":{"country":"","copy":""},"elements":{"w":{"type":"Text","props":{"text":"w"},
              "watch":{"/country":{"action":"setState","params":{"statePath":"/copy","value":{"$state":"/country"}}}}}}}
            """#)
        let observer = RecordingObserver()
        let store = StateStore(initial: spec.state)
        let model = RenderModel(
            spec: spec, catalog: try .standard, store: store, observer: observer)
        let watchers = await model.startWatchers()
        defer { watchers.cancel() }
        await store.set("/country", "")  // equal value: no commit, no fire
        await store.set("/other", 1)  // another path: no fire
        await store.set("/country", "UK")
        await waitForState(store, "/copy", equals: "UK")
        #expect(observer.entries.filter { $0.hasSuffix(":setState") } == ["w:setState"])
    }

    @Test func warningsAreRecordedOnce() throws {
        let spec = try decode(#"{"root":"x","elements":{"x":{"type":"Nope"}}}"#)
        let model = RenderModel(spec: spec, catalog: try .standard)
        model.record(.unknownType(id: "x", type: "Nope"))
        model.record(.unknownType(id: "x", type: "Nope"))
        #expect(model.warnings == [.unknownType(id: "x", type: "Nope")])
        #expect(model.walk().fallbacks == [.unknownType(id: "x", type: "Nope")])
    }

    @Test func missingRootAndDanglingChildAreReported() throws {
        let missingRoot = RenderModel(
            spec: Spec(root: "r", elements: [:]), catalog: try .standard)
        #expect(missingRoot.walk().warnings == [.missingElement(id: "r")])
        let dangling = try decode(
            #"{"root":"s","elements":{"s":{"type":"Stack","children":["late"]}}}"#)
        let model = RenderModel(spec: dangling, catalog: try .standard)
        #expect(model.plan.dangling == ["late"])
        #expect(model.walk().fallbacks == [.missingElement(id: "late")])
    }

    @Test func specUpdateRebuildsThePlanOnlyOnChange() throws {
        let first = try decode(
            #"{"root":"t","elements":{"t":{"type":"Text","props":{"text":"a"}}}}"#)
        let model = RenderModel(spec: first, catalog: try .standard)
        let plan = model.plan
        model.update(spec: first)
        #expect(model.plan == plan)
        let second = try decode(
            #"{"root":"t","elements":{"t":{"type":"Heading","props":{"text":"a"}}}}"#)
        model.update(spec: second)
        #expect(model.plan.nodes["t"]?.type == "Heading")
    }

    @Test func snapshotModelUsesTheSnapshotPlan() throws {
        let spec = try decode(#"{"root":"s","elements":{"s":{"type":"Stack","children":["a"]}}}"#)
        let snapshot = SpecSnapshot(version: 1, spec: spec)
        let model = RenderModel(snapshot: snapshot, catalog: try .standard, store: StateStore())
        #expect(model.plan == snapshot.plan)
        let next = SpecSnapshot(
            version: 2,
            spec: Spec(
                root: "s",
                elements: spec.elements.merging(["a": UIElement(type: "Text", props: ["text": "x"])]
                ) { $1 }))
        model.update(snapshot: next)
        #expect(model.plan == next.plan)
        #expect(model.plan.dangling.isEmpty)
    }

    @Test func firstPrimaryButtonOwnsTheDefaultAction() throws {
        let spec = try decode(
            #"""
            {"root":"s","elements":{"s":{"type":"Stack","children":["a","b","c"]},
              "a":{"type":"Button","props":{"label":"A","variant":"secondary"}},
              "b":{"type":"Button","props":{"label":"B","variant":"primary"}},
              "c":{"type":"Button","props":{"label":"C","variant":"primary"}}}}
            """#)
        let model = RenderModel(spec: spec, catalog: try .standard)
        #expect(model.defaultActionElementID == "b")
    }
}
