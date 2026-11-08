import Testing

@testable import JSONRenderCore

/// jr-2p: a bad patch in mixed mode is an error, not prose; a definite syntax error in
/// object mode fails at once.
@Suite("Decoder strictness")
struct DecoderStrictnessTests {
    static func decode(_ text: String, mode: SpecStreamDecoder.Mode) -> [SpecStreamEvent] {
        var decoder = SpecStreamDecoder(mode: mode)
        return decoder.push(text) + decoder.flush()
    }

    @Test("Mixed: a JSON line with an unknown op is a bad line, outside and inside the fence")
    func mixedUnknownOp() {
        let text = """
            Intro
            {"op":"frobnicate","path":"/x"}
            ```spec
            {"op":"frobnicate","path":"/x"}
            {"op":"add","path":"/root","value":"main"}
            ```
            Outro

            """
        let events = Self.decode(text, mode: .mixed)
        #expect(
            events == [
                .text("Intro"),
                .error(.badLine(index: 1, reason: "no op/path")),
                .error(.badLine(index: 3, reason: "no op/path")),
                .patch(SpecPatch(op: .add, path: "/root", value: "main")),
                .text("Outro"),
            ])
    }

    @Test("Mixed: a known op without a path is a bad line")
    func mixedNoPath() {
        #expect(
            Self.decode(#"{"op":"add","value":1}"# + "\n", mode: .mixed) == [
                .error(.badLine(index: 0, reason: "no op/path"))
            ])
    }

    @Test("Mixed: prose and a JSON object without op stay text (upstream)")
    func mixedProseStaysText() {
        let text = "{\"not\":\"a patch\"}\n{curly prose}\n{\"op\":3}\n"
        #expect(
            Self.decode(text, mode: .mixed) == [
                .text("{\"not\":\"a patch\"}"), .text("{curly prose}"), .text("{\"op\":3}"),
            ])
    }

    @Test("Object: a definite syntax error fails once at the push that completes it")
    func objectFailsFast() {
        var decoder = SpecStreamDecoder(mode: .object)
        #expect(
            decoder.push(#"{"root": "a", "#).contains {
                $0 == .patch(SpecPatch(op: .add, path: "/root", value: "a"))
            })
        #expect(decoder.push("]") == [.error(.unrecoverable("invalid JSON"))])
        #expect(decoder.push(#""elements":{}}"#).isEmpty)
        #expect(decoder.flush().isEmpty)
        #expect(decoder.bufferedBytes == 0)
    }

    @Test("Object: a cut inside a string, a number or an escape is not an error")
    func objectCutsAreNotErrors() {
        for prefix in [
            #"{"root":"ma"#, #"{"root":"main","state":{"n":12"#, #"{"root":"a\"#,
            #"{"root":"\u00"#, #"{"root":"main","state":{"ok":tr"#, #"{"ro"#,
        ] {
            var decoder = SpecStreamDecoder(mode: .object)
            let events = decoder.push(prefix)
            #expect(!events.contains { if case .error = $0 { true } else { false } }, "\(prefix)")
            #expect(TolerantJSON.parse(Array(prefix.utf8)[...]).cutPath != nil, "\(prefix)")
        }
    }
}
