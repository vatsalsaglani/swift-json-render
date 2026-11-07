import Testing

@testable import JSONRenderCore

/// The 33 upstream stream cases (`Tests/ParityFixtures/upstream/streams`).
@Suite("Stream parity")
struct StreamParityTests {
    /// Upstream records the patch objects it applied by reference; a later `-` append into
    /// the same array mutates the recorded `add` value. Swift values are not shared, so the
    /// recorded value stays as it was applied. Case → patch index with the aliased value.
    static let aliasedPatchValues: [String: [Int: JSONValue]] = [
        "compiler-identical-append-lines-apply-twice": [0: []]
    ]

    @Test("All 33 cases are present")
    func inventory() {
        #expect(StreamFixtures.upstream.count == 33)
        #expect(StreamFixtures.upstream(kind: "compile").count == 8)
        #expect(StreamFixtures.upstream(kind: "compiler").count == 7)
        #expect(StreamFixtures.upstream(kind: "spec-patch").count == 5)
        #expect(StreamFixtures.upstream(kind: "mixed").count == 13)
    }

    @Test("compileSpecStream", arguments: StreamFixtures.upstream(kind: "compile"))
    func compile(_ fixture: StreamCase) {
        let initial = fixture.expected["initial"] ?? .object([:])
        let compiled = SpecStreamCompiler.compile(fixture.input, initial: initial)
        #expect(compiled.result == fixture.expected["result"])
        expectPatches(compiled.patches, fixture)
        #expect(compiled.journal.isEmpty)
    }

    @Test("createSpecStreamCompiler", arguments: StreamFixtures.upstream(kind: "compiler"))
    func compiler(_ fixture: StreamCase) throws {
        let chunks = try #require(fixture.expected["chunks"]?.arrayValue).compactMap(\.stringValue)
        let pushes = try #require(fixture.expected["pushes"]?.arrayValue)
        #expect(chunks.joined() == fixture.input)
        var decoder = SpecStreamDecoder(mode: .jsonl)
        var result: JSONValue = .object([:])
        var patches: [SpecPatch] = []
        func apply(_ events: [SpecStreamEvent]) -> Int {
            var count = 0
            for case .patch(let patch) in events {
                try? result.apply(patch)
                patches.append(patch)
                count += 1
            }
            return count
        }
        for (index, chunk) in chunks.enumerated() {
            let count = apply(decoder.push(chunk))
            #expect(Double(count) == pushes[index]["newPatches"]?.numberValue, "push \(index)")
        }
        if fixture.expected["reset"] == true {
            decoder = SpecStreamDecoder(mode: .jsonl)
            result = .object([:])
            patches = []
        }
        _ = apply(decoder.flush())
        #expect(result == fixture.expected["result"])
        expectPatches(patches, fixture)
    }

    @Test("applySpecPatch", arguments: StreamFixtures.upstream(kind: "spec-patch"))
    func specPatch(_ fixture: StreamCase) throws {
        var result = try #require(fixture.expected["initial"])
        var patches: [SpecPatch] = []
        for line in fixture.input.split(separator: "\n") {
            let patch = try SpecStreamDecoder.parseLine(String(line)).get()
            try result.apply(patch)
            patches.append(patch)
        }
        #expect(result == fixture.expected["result"])
        expectPatches(patches, fixture)
    }

    @Test("createMixedStreamParser", arguments: StreamFixtures.upstream(kind: "mixed"))
    func mixed(_ fixture: StreamCase) throws {
        let chunks = try #require(fixture.expected["chunks"]?.arrayValue).compactMap(\.stringValue)
        #expect(chunks.joined() == fixture.input)
        var decoder = SpecStreamDecoder(mode: .mixed)
        var events: [SpecStreamEvent] = []
        for chunk in chunks { events += decoder.push(chunk) }
        if fixture.expected["flush"] == true { events += decoder.flush() }
        #expect(!events.contains { if case .error = $0 { true } else { false } })
        #expect(.array(fixtureEvents(events)) == fixture.expected["events"])
    }

    private func expectPatches(_ patches: [SpecPatch], _ fixture: StreamCase) {
        guard let expected = fixture.expected["patches"]?.arrayValue else {
            Issue.record("no patches in \(fixture.name)")
            return
        }
        #expect(patches.count == expected.count)
        let aliased = StreamParityTests.aliasedPatchValues[fixture.name] ?? [:]
        for (index, (patch, json)) in zip(patches, expected).enumerated() {
            var wanted = fixturePatch(json)
            if let value = aliased[index] { wanted?.value = value }
            #expect(patch == wanted, "patch \(index)")
        }
    }
}
