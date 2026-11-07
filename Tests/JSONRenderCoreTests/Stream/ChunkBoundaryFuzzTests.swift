import Testing

@testable import JSONRenderCore

/// Every transcript gives the same events whatever the chunk boundaries are.
@Suite("Chunk-boundary fuzz")
struct ChunkBoundaryFuzzTests {
    static let seed: UInt64 = 0x6A72_325F_7374_726D  // "jr2_strm"

    static func mode(for fixture: StreamCase) -> SpecStreamDecoder.Mode {
        fixture.kind == "mixed" ? .mixed : .jsonl
    }

    static func decode(_ chunks: [String], mode: SpecStreamDecoder.Mode) -> [SpecStreamEvent] {
        var decoder = SpecStreamDecoder(mode: mode)
        var events: [SpecStreamEvent] = []
        for chunk in chunks { events += decoder.push(chunk) }
        return events + decoder.flush()
    }

    static func decode(bytes chunks: [ArraySlice<UInt8>], mode: SpecStreamDecoder.Mode)
        -> [SpecStreamEvent]
    {
        var decoder = SpecStreamDecoder(mode: mode)
        var events: [SpecStreamEvent] = []
        for chunk in chunks { events += decoder.push(bytes: chunk) }
        return events + decoder.flush()
    }

    @Test("Every two-way split on a scalar boundary", arguments: StreamFixtures.transcripts)
    func everyTwoWaySplit(_ fixture: StreamCase) {
        let mode = ChunkBoundaryFuzzTests.mode(for: fixture)
        let whole = ChunkBoundaryFuzzTests.decode([fixture.input], mode: mode)
        #expect(!whole.isEmpty || fixture.name == "mixed-skips-empty-lines")
        let scalars = fixture.input.unicodeScalars
        for split in scalars.indices {
            let head = String(scalars[..<split])
            let tail = String(scalars[split...])
            let events = ChunkBoundaryFuzzTests.decode([head, tail], mode: mode)
            #expect(
                events == whole,
                "split at scalar offset \(scalars.distance(from: scalars.startIndex, to: split))")
        }
    }

    @Test("Every two-way split at a byte offset", arguments: StreamFixtures.transcripts)
    func everyByteSplit(_ fixture: StreamCase) {
        let mode = ChunkBoundaryFuzzTests.mode(for: fixture)
        let bytes = Array(fixture.input.utf8)
        let whole = ChunkBoundaryFuzzTests.decode(bytes: [bytes[...]], mode: mode)
        for split in 0...bytes.count {
            let events = ChunkBoundaryFuzzTests.decode(
                bytes: [bytes[..<split], bytes[split...]], mode: mode)
            #expect(events == whole, "split at byte \(split)")
        }
    }

    @Test("200 seeded three-way splits", arguments: StreamFixtures.transcripts)
    func randomThreeWaySplits(_ fixture: StreamCase) {
        let mode = ChunkBoundaryFuzzTests.mode(for: fixture)
        let bytes = Array(fixture.input.utf8)
        let whole = ChunkBoundaryFuzzTests.decode(bytes: [bytes[...]], mode: mode)
        let seed = ChunkBoundaryFuzzTests.seed ^ UInt64(bytes.count)
        var random = SplitMix64(seed: seed)
        for round in 0..<200 {
            let cuts = [
                Int.random(in: 0...bytes.count, using: &random),
                Int.random(in: 0...bytes.count, using: &random),
            ].sorted()
            let chunks = [bytes[..<cuts[0]], bytes[cuts[0]..<cuts[1]], bytes[cuts[1]...]]
            let events = ChunkBoundaryFuzzTests.decode(bytes: chunks, mode: mode)
            #expect(events == whole, "seed \(seed) round \(round) cuts \(cuts)")
        }
    }

    /// Identical events give an identical result; this checks the applied result directly on
    /// the upstream JSONL transcripts (the own transcripts are larger and add only time).
    @Test(
        "The compiled result is the same at every split",
        arguments: StreamFixtures.upstream.filter { $0.kind != "mixed" })
    func resultAtEverySplit(_ fixture: StreamCase) {
        let whole = SpecStreamCompiler.compile(fixture.input)
        let bytes = Array(fixture.input.utf8)
        for split in 0...bytes.count {
            var decoder = SpecStreamDecoder(mode: .jsonl)
            var result: JSONValue = .object([:])
            let events =
                decoder.push(bytes: bytes[..<split]) + decoder.push(bytes: bytes[split...])
                + decoder.flush()
            for case .patch(let patch) in events { try? result.apply(patch) }
            #expect(result == whole.result, "split at byte \(split)")
        }
    }

    @Test("A UTF-8 scalar split across chunks decodes intact")
    func splitScalar() throws {
        let line = #"{"op":"add","path":"/t","value":"héllo — 日本 🎉"}"# + "\n"
        let bytes = Array(line.utf8)
        let whole = ChunkBoundaryFuzzTests.decode(bytes: [bytes[...]], mode: .jsonl)
        let patch = try #require(whole.first)
        #expect(patch == .patch(SpecPatch(op: .add, path: "/t", value: "héllo — 日本 🎉")))
        for split in 0...bytes.count {
            #expect(
                ChunkBoundaryFuzzTests.decode(
                    bytes: [bytes[..<split], bytes[split...]], mode: .jsonl)
                    == whole, "split at byte \(split)")
            #expect(
                ChunkBoundaryFuzzTests.decode(
                    bytes: [bytes[..<split], bytes[split...]], mode: .mixed)
                    == whole, "mixed split at byte \(split)")
        }
    }

    @Test("CRLF lines split like LF lines")
    func crlf() {
        let text = "{\"op\":\"add\",\"path\":\"/a\",\"value\":1}\r\nhello\r\n"
        let events = ChunkBoundaryFuzzTests.decode([text], mode: .mixed)
        #expect(events == [.patch(SpecPatch(op: .add, path: "/a", value: 1)), .text("hello\r")])
    }

    @Test("A line over the buffer limit is one error at the same index, whatever the chunks")
    func overlongLine() {
        let long =
            #"{"op":"add","path":"/a","value":""# + String(repeating: "x", count: 100) + "\"}"
        let text = long + "\n" + #"{"op":"add","path":"/b","value":1}"# + "\n"
        let bytes = Array(text.utf8)
        var reference = SpecStreamDecoder(mode: .jsonl, bufferLimit: 64)
        let whole = reference.push(text) + reference.flush()
        #expect(
            whole == [
                .error(.badLine(index: 0, reason: "line too long")),
                .patch(SpecPatch(op: .add, path: "/b", value: 1)),
            ])
        for split in 0...bytes.count {
            var decoder = SpecStreamDecoder(mode: .jsonl, bufferLimit: 64)
            let events =
                decoder.push(bytes: bytes[..<split]) + decoder.push(bytes: bytes[split...])
                + decoder.flush()
            #expect(events == whole, "split at byte \(split)")
            #expect(decoder.bufferedBytes == 0)
        }
    }
}
