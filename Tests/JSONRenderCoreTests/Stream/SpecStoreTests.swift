import Testing

@testable import JSONRenderCore

@Suite("SpecStore")
struct SpecStoreTests {
    static func patches(_ text: String) -> [SpecPatch] {
        var decoder = SpecStreamDecoder(mode: .jsonl)
        return (decoder.push(text) + decoder.flush()).compactMap {
            if case .patch(let patch) = $0 { patch } else { nil }
        }
    }

    static func card(_ children: [String]) -> JSONValue {
        ["type": "Card", "props": [:], "children": .array(children.map(JSONValue.string))]
    }

    @Test(
        "Own transcripts: dangling after each line, final order and journal",
        arguments: StreamFixtures.own.filter { $0.name != "object-mode-fragments" })
    func ownTranscripts(_ fixture: StreamCase) async throws {
        let store = SpecStore(catalog: Catalog())
        var decoder = SpecStreamDecoder(mode: .jsonl)
        let lines = fixture.input.split(separator: "\n", omittingEmptySubsequences: false)
        var ids: [String: Set<String>] = [:]
        for (index, line) in lines.enumerated() {
            await store.apply(decoder.push(line + "\n"))
            let snapshot = await store.current
            ids[String(index)] = snapshot.dangling
        }
        await store.apply(decoder.flush())
        let expect = fixture.expected
        if case .object(let wanted)? = expect["danglingAfter"] {
            for (line, value) in wanted {
                let set = Set((value.arrayValue ?? []).compactMap(\.stringValue))
                #expect(ids[line] == set, "after line \(line)")
            }
        }
        let last = await store.current
        #expect(last.plan.rootID == expect["rootID"]?.stringValue)
        #expect(.array(last.plan.order.map(JSONValue.string)) == expect["order"])
        #expect(Double(last.journal.count) == expect["journal"]?.numberValue)
        if let badLines = expect["badLines"]?.arrayValue {
            let indexes = last.journal.compactMap { error -> Double? in
                if case .badLine(let index, _) = error { Double(index) } else { nil }
            }
            #expect(indexes == badLines.compactMap(\.numberValue))
        }
        if let count = expect["dataCount"]?.numberValue {
            #expect(
                Double(last.spec.elements["c1"]?.props["data"]?.arrayValue?.count ?? -1) == count)
        }
    }

    @Test("Out of order: ids stay stable and dangling shrinks")
    func outOfOrder() async {
        let store = SpecStore(catalog: Catalog())
        await store.apply(SpecPatch(op: .add, path: "/root", value: "main"))
        await store.apply(
            SpecPatch(op: .add, path: "/elements/main", value: Self.card(["a", "b"])))
        #expect(await store.current.dangling == ["a", "b"])
        await store.apply(SpecPatch(op: .add, path: "/elements/b", value: ["type": "Text"]))
        #expect(await store.current.dangling == ["a"])
        await store.apply(SpecPatch(op: .add, path: "/elements/a", value: ["type": "Text"]))
        let snapshot = await store.current
        #expect(snapshot.dangling.isEmpty)
        #expect(snapshot.plan.order == ["main", "a", "b"])
    }

    @Test("Root last: rootID is nil until the root arrives")
    func rootLast() async {
        let store = SpecStore(catalog: Catalog())
        await store.apply(SpecPatch(op: .add, path: "/elements/main", value: Self.card([])))
        #expect(await store.current.plan.rootID == nil)
        await store.apply(SpecPatch(op: .add, path: "/root", value: "main"))
        #expect(await store.current.plan.rootID == "main")
    }

    @Test("A test mismatch is journaled and later patches still apply")
    func testMismatch() async {
        let store = SpecStore(catalog: Catalog())
        let errors = await store.apply([
            SpecPatch(op: .add, path: "/state", value: ["n": 1]),
            SpecPatch(op: .test, path: "/state/n", value: 2),
            SpecPatch(op: .add, path: "/state/m", value: 3),
        ])
        #expect(
            errors == [.patchFailed(index: 1, op: .test, path: "/state/n", reason: "test mismatch")]
        )
        let snapshot = await store.current
        #expect(snapshot.spec.state == ["n": 1, "m": 3])
        #expect(snapshot.journal == errors)
    }

    @Test("__proto__ is refused; move and copy without from are no-ops")
    func refusals() async {
        let store = SpecStore(catalog: Catalog())
        let errors = await store.apply([
            SpecPatch(op: .add, path: "/state/__proto__/x", value: 1),
            SpecPatch(op: .move, path: "/state/a"),
            SpecPatch(op: .copy, path: "/state/b"),
        ])
        #expect(
            errors == [
                .patchFailed(index: 0, op: .add, path: "/state/__proto__/x", reason: "invalid path")
            ])
        #expect(await store.current.spec.state == nil)
    }

    @Test("The 2,001st element breaches the element budget and freezes the store")
    func elementBudget() async {
        let store = SpecStore(catalog: Catalog())
        var elements: [String: JSONValue] = [:]
        for index in 0..<SpecLimits.defaultMaxElements { elements["e\(index)"] = ["type": "Text"] }
        #expect(
            await store.apply([SpecPatch(op: .add, path: "/elements", value: .object(elements))])
                .isEmpty)
        let good = await store.current
        let errors = await store.apply([
            SpecPatch(op: .add, path: "/elements/extra", value: ["type": "Text"]),
            SpecPatch(op: .add, path: "/root", value: "e0"),
        ])
        #expect(errors == [.budget(.elements), .budget(.elements)])
        let snapshot = await store.current
        #expect(snapshot.spec == good.spec)
        #expect(snapshot.journal == [.budget(.elements)])
        // Later patches are refused too, and the journal holds the breach once.
        #expect(
            await store.apply(SpecPatch(op: .add, path: "/root", value: "e1")) == .budget(.elements)
        )
        #expect(await store.current.journal == [.budget(.elements)])
    }

    @Test("256 KiB + 1 breaches the byte budget")
    func byteBudget() async {
        let store = SpecStore(catalog: Catalog())
        let big = String(repeating: "x", count: SpecLimits.defaultMaxBytes / 2 + 1)
        let error = await store.apply(
            SpecPatch(op: .add, path: "/state", value: ["text": .string(big)]))
        #expect(error == .budget(.bytes))
        #expect(await store.current.spec.state == nil)
        let small = SpecStore(catalog: Catalog(), limits: SpecLimits(maxBytes: 1_000))
        #expect(await small.apply(SpecPatch(op: .add, path: "/state", value: ["t": "ok"])) == nil)
        #expect(
            await small.apply(
                SpecPatch(
                    op: .add, path: "/state/t", value: .string(String(repeating: "y", count: 600))))
                == .budget(.bytes))
    }

    @Test("Replacing a value does not grow the byte estimate")
    func replaceDoesNotGrow() async {
        let store = SpecStore(catalog: Catalog(), limits: SpecLimits(maxBytes: 2_000))
        let value = JSONValue.string(String(repeating: "z", count: 300))
        for _ in 0..<50 {
            #expect(
                await store.apply(SpecPatch(op: .replace, path: "/state/t", value: value)) == nil)
        }
    }

    @Test("finish prunes dangling children and slots and validates after the prune")
    func finishPrunes() async {
        let store = SpecStore(catalog: Catalog())
        await store.apply([
            SpecPatch(op: .add, path: "/root", value: "main"),
            SpecPatch(
                op: .add, path: "/elements/main",
                value: [
                    "type": "Card", "children": ["a", "gone"], "slots": ["footer": ["lost", "a"]],
                ]),
            SpecPatch(op: .add, path: "/elements/a", value: ["type": "Text"]),
        ])
        #expect(await store.current.dangling == ["gone", "lost"])
        let (report, final) = await store.finish()
        #expect(final.isFinal)
        #expect(final.dangling.isEmpty)
        #expect(final.plan.dangling.isEmpty)
        #expect(final.spec.elements["main"]?.children == ["a"])
        #expect(final.spec.elements["main"]?.slots == ["footer": ["a"]])
        #expect(report.issues.filter { $0.code == .missingChild }.isEmpty)
        // Closed: later patches are refused, and finish returns the same result.
        #expect(
            await store.apply(SpecPatch(op: .add, path: "/root", value: "x"))
                == .unrecoverable("store closed"))
        let again = await store.finish()
        #expect(again.1 == final)
    }

    @Test("finish without prune reports missing children")
    func finishWithoutPrune() async {
        let store = SpecStore(catalog: Catalog())
        await store.apply([
            SpecPatch(op: .add, path: "/root", value: "main"),
            SpecPatch(op: .add, path: "/elements/main", value: Self.card(["gone"])),
        ])
        let (report, final) = await store.finish(prune: false)
        #expect(report.issues.contains { $0.code == .missingChild })
        #expect(final.spec.elements["main"]?.children == ["gone"])
    }

    @Test("cancel keeps the last snapshot, not final")
    func cancel() async {
        let store = SpecStore(catalog: Catalog())
        await store.apply(SpecPatch(op: .add, path: "/root", value: "main"))
        let before = await store.current
        let last = await store.cancel()
        #expect(last == before)
        #expect(!last.isFinal)
        #expect(await store.isClosed)
        #expect(await store.apply(SpecPatch(op: .add, path: "/root", value: "x")) != nil)
        #expect(await store.current == before)
    }

    @Test("Two subscribers receive the same versions; streams end at finish")
    func twoSubscribers() async {
        let store = SpecStore(catalog: Catalog())
        let first = await store.snapshots(bufferingPolicy: .unbounded)
        let second = await store.snapshots(bufferingPolicy: .unbounded)
        #expect(await store.subscriberCount == 2)
        await store.apply(SpecPatch(op: .add, path: "/root", value: "a"))
        await store.apply(SpecPatch(op: .add, path: "/root", value: "b"))
        _ = await store.finish()
        var firstVersions: [UInt64] = []
        for await snapshot in first { firstVersions.append(snapshot.version) }
        var secondVersions: [UInt64] = []
        for await snapshot in second { secondVersions.append(snapshot.version) }
        #expect(firstVersions == [0, 1, 2, 3])
        #expect(secondVersions == firstVersions)
        #expect(await store.subscriberCount == 0)
        // A subscriber after the end gets the final snapshot and an ended stream.
        var late: [Bool] = []
        for await snapshot in await store.snapshots() { late.append(snapshot.isFinal) }
        #expect(late == [true])
    }

    @Test("A terminated subscriber is removed")
    func termination() async {
        let store = SpecStore(catalog: Catalog())
        do {
            let stream = await store.snapshots()
            var iterator = stream.makeAsyncIterator()
            _ = await iterator.next()
        }
        // The stream was released; the removal hops back to the actor.
        let probe = await store.snapshots(bufferingPolicy: .unbounded)
        await store.apply(SpecPatch(op: .add, path: "/root", value: "a"))
        var versions: [UInt64] = []
        for await snapshot in probe {
            versions.append(snapshot.version)
            if versions.count == 2 { break }
        }
        #expect(versions == [0, 1])
    }

    @Test("One snapshot per apply(_ patches:)")
    func oneCommitPerBatch() async {
        let store = SpecStore(catalog: Catalog())
        let stream = await store.snapshots(bufferingPolicy: .unbounded)
        let batch = (0..<40).map {
            SpecPatch(op: .add, path: "/elements/e\($0)", value: ["type": "Text"])
        }
        await store.apply(batch)
        await store.apply(
            SpecStreamEvent.patch(SpecPatch(op: .add, path: "/root", value: "e0")).asArray)
        _ = await store.cancel()
        var versions: [UInt64] = []
        for await snapshot in stream { versions.append(snapshot.version) }
        #expect(versions == [0, 1, 2])
    }

    @Test("Decoder errors and text events: errors journal, text is ignored")
    func events() async {
        let store = SpecStore(catalog: Catalog())
        let errors = await store.apply([
            .text("hello"), .error(.badLine(index: 3, reason: "not an object")),
            .patch(SpecPatch(op: .add, path: "/root", value: "main")),
        ])
        #expect(errors == [.badLine(index: 3, reason: "not an object")])
        let snapshot = await store.current
        #expect(snapshot.version == 1)
        #expect(snapshot.spec.root == "main")
        await store.note(.unrecoverable("Transport"))
        #expect(await store.current.journal.count == 2)
        #expect(await store.current.version == 2)
    }

    @Test("reset starts again from the given spec")
    func reset() async {
        let store = SpecStore(catalog: Catalog())
        await store.apply(SpecPatch(op: .test, path: "/x", value: 1))
        _ = await store.cancel()
        await store.reset(Spec(root: "r", elements: ["r": UIElement(type: "Card")]))
        let snapshot = await store.current
        #expect(snapshot.journal.isEmpty)
        #expect(snapshot.plan.rootID == "r")
        #expect(!(await store.isClosed))
        #expect(await store.apply(SpecPatch(op: .add, path: "/state", value: ["a": 1])) == nil)
    }

    @Test("Patch mode: applying(_:to:catalog:)")
    func patchMode() async {
        let spec = Spec(
            root: "main", elements: ["main": UIElement(type: "Card", props: ["title": "Old"])])
        let (result, errors, report) = await SpecStore.applying(
            [
                SpecPatch(op: .replace, path: "/elements/main/props/title", value: "New"),
                SpecPatch(op: .test, path: "/root", value: "nope"),
            ], to: spec, catalog: Catalog())
        #expect(result.elements["main"]?.props["title"] == "New")
        #expect(errors.count == 1)
        #expect(report.valid)
    }
}

extension SpecStreamEvent {
    fileprivate var asArray: [SpecStreamEvent] { [self] }
}
