import Foundation
import Testing

@testable import JSONRenderCore

@Suite("Spec decoding")
struct SpecDecodeTests {
    @Test(
        "The eight upstream specs decode with no unknown keys",
        arguments: JSONValueTests.specFixtureFiles())
    func upstreamSpecs(_ file: String) throws {
        let decoded = try Spec.decode(ParityFixtures.data("specs/\(file)"))
        let unexpected = decoded.warnings.filter {
            if case .singleBindingNormalised = $0 { return false }
            return true
        }
        #expect(unexpected.isEmpty)
        #expect(decoded.spec.elements[decoded.spec.root] != nil)
    }

    @Test("Null props are kept")
    func nullProps() throws {
        let json = #"{"root":"a","elements":{"a":{"type":"Card","props":{"description":null}}}}"#
        let spec = try Spec.decode(Data(json.utf8)).spec
        #expect(spec.elements["a"]?.props["description"] == .null)
        #expect(spec.elements["a"]?.props.keys.contains("description") == true)
    }

    @Test("A single on binding becomes an array, with a warning")
    func singleBinding() throws {
        let decoded = try Spec.decode(ParityFixtures.data("specs/confetti.json"))
        let element = decoded.spec.elements.values.first { $0.on != nil }
        #expect(element?.on?["press"]?.count == 1)
        #expect(element?.on?["press"]?.first?.action == "confetti")
        #expect(
            decoded.warnings.contains { warning in
                if case .singleBindingNormalised(_, "press") = warning { return true }
                return false
            })
    }

    @Test("Unknown element keys are reported and dropped")
    func unknownKeys() throws {
        let json = #"{"root":"a","elements":{"a":{"type":"T","props":{},"bogus":1}}}"#
        let decoded = try Spec.decode(Data(json.utf8))
        #expect(decoded.warnings == [.unknownElementKey(element: "a", key: "bogus")])
    }

    @Test("Size cap is checked before parsing")
    func sizeCap() {
        let limits = SpecLimits(maxBytes: 10)
        #expect(throws: SpecDecodeError.tooLarge(bytes: 11, limit: 10)) {
            try Spec.decode(Data("{\"root\":\"\"}".utf8), limits: limits)
        }
        let big = Data(repeating: 0x20, count: SpecLimits.defaultMaxBytes + 1)
        #expect(
            throws: SpecDecodeError.tooLarge(bytes: big.count, limit: SpecLimits.defaultMaxBytes)
        ) {
            try Spec.decode(big)
        }
    }

    @Test("Invalid JSON and wrong shapes throw")
    func errors() {
        #expect {
            try Spec.decode(Data("{not json".utf8))
        } throws: { error in
            if case .invalidJSON = error as? SpecDecodeError { return true }
            return false
        }
        #expect {
            try Spec.decode(Data(#"{"root":"a","elements":{"a":{"props":{}}}}"#.utf8))
        } throws: { error in
            if case .shape = error as? SpecDecodeError { return true }
            return false
        }
        #expect {
            try Spec.decode(Data(#"{"root":"a","elements":{"a":{"type":"T","on":{"x":3}}}}"#.utf8))
        } throws: { error in
            if case .shape = error as? SpecDecodeError { return true }
            return false
        }
    }

    @Test("Limits clamp downward only")
    func limitsClamp() {
        let raised = SpecLimits(
            maxBytes: 10_000_000, maxElements: 9_999, maxDepth: 500, maxRepeatRows: 10_000)
        #expect(raised == .default)
        let lowered = SpecLimits(maxBytes: 1_024, maxElements: 10, maxDepth: 4, maxRepeatRows: 5)
        #expect(lowered.maxBytes == 1_024)
        #expect(lowered.maxElements == 10)
        #expect(lowered.maxDepth == 4)
        #expect(lowered.maxRepeatRows == 5)
        #expect(SpecLimits(maxDepth: -3).maxDepth == 0)
    }

    /// jr-1b's validator fixtures must decode, including malformed `visible` shapes and
    /// fields placed inside props, so the validator can report them.
    @Test("Every validator fixture spec decodes", arguments: SpecDecodeTests.validatorSpecFiles())
    func validatorSpecsDecode(_ file: String) throws {
        let spec = try Spec.decode(ParityFixtures.data("validator/\(file)")).spec
        // Lossless: visible conditions encode back to their input.
        let original = try ParityFixtures.json("validator/\(file)")
        for (id, element) in spec.elements {
            #expect(element.visible?.jsonValue == original["elements"]?[id]?["visible"])
        }
    }

    static func validatorSpecFiles() -> [String] {
        let url = ParityFixtures.url("validator")
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        return names.filter { $0.hasSuffix(".spec.json") }.sorted()
    }

    @Test("Strict visibility validation matches the upstream strict schema")
    func strictVisibility() throws {
        let mixed = try Spec.decode(
            ParityFixtures.data("validator/visible-mixing-state-and-item-rejected.spec.json")
        ).spec
        #expect(mixed.elements["root"]?.visible?.isStrictlyValid == false)
        let unknown = try Spec.decode(
            ParityFixtures.data("validator/visible-unknown-shape-rejected.spec.json")
        ).spec
        #expect(unknown.elements["root"]?.visible?.isStrictlyValid == false)
        for file in [
            "visible-or-with-nested-and", "visible-implicit-and-array", "visible-index-lt",
            "visible-item-eq", "visible-state-eq", "visible-true", "visible-false",
        ] {
            let spec = try Spec.decode(ParityFixtures.data("validator/\(file).spec.json")).spec
            #expect(spec.elements["root"]?.visible?.isStrictlyValid == true, "\(file)")
        }
    }

    @Test("Codable decode and encode of UIElement and RepeatConfig")
    func elementCodable() throws {
        let json = #"""
            {"type":"List","props":{"a":1},"children":["x"],"slots":{"header":["h"]},
             "repeat":{"statePath":{"$item":"rows"},"key":"id"},
             "watch":{"/a":[{"action":"setState","params":{"statePath":"/b","value":1}}]}}
            """#
        let element = try JSONDecoder().decode(UIElement.self, from: Data(json.utf8))
        #expect(element.repeat == RepeatConfig(statePath: .item("rows"), key: "id"))
        #expect(element.slots == ["header": ["h"]])
        #expect(element.watch?["/a"]?.first?.params?["statePath"] == "/b")
        let back = try JSONDecoder().decode(UIElement.self, from: JSONEncoder().encode(element))
        #expect(back == element)
    }
}
