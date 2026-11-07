import Testing

@testable import JSONRenderCore

@Suite("Tolerant JSON")
struct TolerantJSONTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let input: String
        let value: JSONValue?
        let complete: Bool
        var testDescription: String { input }
    }

    static let rows: [Row] = [
        Row(input: #"{"a":1}"#, value: ["a": 1], complete: true),
        Row(input: #"{"a":"hel"#, value: ["a": "hel"], complete: false),
        Row(input: #"[1,2,"#, value: [1, 2], complete: false),
        Row(input: #"[1,2"#, value: [1], complete: false),
        Row(input: #"{"a":{"b":{"c":true"#, value: ["a": ["b": ["c": true]]], complete: false),
        Row(input: #"{"a":1,"#, value: ["a": 1], complete: false),
        Row(input: #"{"a":tru"#, value: [:], complete: false),
        Row(input: #"{"a":nul"#, value: [:], complete: false),
        Row(input: #"{"a":-"#, value: [:], complete: false),
        Row(input: #"{"a":1e"#, value: [:], complete: false),
        Row(input: #"{"a":12."#, value: [:], complete: false),
        Row(input: #"{"a":12,"b":"#, value: ["a": 12], complete: false),
        Row(input: #"{"a":12,"b""#, value: ["a": 12], complete: false),
        Row(input: #"{"a":12,"ke"#, value: ["a": 12], complete: false),
        Row(input: #"{"a":"x\""#, value: ["a": "x\""], complete: false),
        Row(input: #"{"a":"x\"#, value: ["a": "x"], complete: false),
        Row(input: #"{"a":"x\u00"#, value: ["a": "x"], complete: false),
        Row(input: #"{"a":"xé"#, value: ["a": "xé"], complete: false),
        Row(input: #"{"a":"🎉"}"#, value: ["a": "🎉"], complete: true),
        Row(input: #"{"a":"\ud83c\u"#, value: ["a": ""], complete: false),
        Row(input: #"{"a":[{"b":null},{"#, value: ["a": [["b": nil], [:]]], complete: false),
        Row(input: #"  "#, value: nil, complete: false),
        Row(input: #"{"a":1}}"#, value: nil, complete: false),
        Row(input: #"{"a":01}"#, value: nil, complete: false),
        Row(input: #"{"a" 1}"#, value: nil, complete: false),
        Row(input: #"hello"#, value: nil, complete: false),
    ]

    @Test("Table", arguments: rows)
    func table(_ row: Row) {
        let result = TolerantJSON.parse(Array(row.input.utf8)[...])
        #expect(result.value == row.value)
        if row.value != nil {
            #expect((result.cutPath == nil) == row.complete)
        }
    }

    @Test("The cut path names the innermost cut value")
    func cutPath() {
        let result = TolerantJSON.parse(
            Array(#"{"elements":{"a":{"type":"Card"},"b":{"ty"#.utf8)[...])
        #expect(result.cutPath == ["elements", "b"])
        let inString = TolerantJSON.parse(Array(#"{"root":"ma"#.utf8)[...])
        #expect(inString.cutPath == ["root"])
    }

    @Test("Nesting past the decode depth is refused")
    func depth() {
        let deep = String(repeating: "[", count: JSONValue.maxDecodeDepth + 1)
        #expect(TolerantJSON.parse(Array(deep.utf8)[...]).value == nil)
        let ok = String(repeating: "[", count: JSONValue.maxDecodeDepth)
        #expect(TolerantJSON.parse(Array(ok.utf8)[...]).value != nil)
    }

    @Test("An incomplete trailing UTF-8 scalar is held back")
    func utf8Prefix() {
        let bytes = Array("aé🎉".utf8)  // 1 + 2 + 4 bytes
        #expect(TolerantJSON.completeUTF8Prefix(bytes) == 7)
        #expect(TolerantJSON.completeUTF8Prefix(Array(bytes[..<6])) == 3)
        #expect(TolerantJSON.completeUTF8Prefix(Array(bytes[..<4])) == 3)
        #expect(TolerantJSON.completeUTF8Prefix(Array(bytes[..<2])) == 1)
    }

    @Test("64 KiB + 1 in object mode is unrecoverable once; later pushes are ignored")
    func bufferLimit() {
        var decoder = SpecStreamDecoder(mode: .object)
        let first = decoder.push(#"{"root":"main","state":{"text":""#)
        #expect(first == [.patch(SpecPatch(op: .add, path: "/root", value: "main"))])
        let filler = String(repeating: "x", count: SpecStreamDecoder.maxBufferLimit)
        #expect(decoder.push(filler) == [.error(.unrecoverable("buffer limit"))])
        #expect(decoder.push(#""}}"#).isEmpty)
        #expect(decoder.flush().isEmpty)
        #expect(decoder.bufferedBytes == 0)
    }

    @Test("The buffer limit is clamped to 64 KiB")
    func clamp() {
        #expect(SpecStreamDecoder(mode: .jsonl, bufferLimit: 1 << 30).bufferLimit == 64 * 1024)
        #expect(SpecStreamDecoder(mode: .jsonl, bufferLimit: 0).bufferLimit == 1)
    }
}
