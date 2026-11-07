import Foundation
import Testing

@testable import JSONRenderCore

@Suite("Object mode")
struct ObjectModeTests {
    static func fragments() throws -> (fragments: [String], expected: JSONValue) {
        let fixture = try #require(StreamFixtures.own.first { $0.name == "object-mode-fragments" })
        let document = try JSONDecoder().decode(JSONValue.self, from: Data(fixture.input.utf8))
        let fragments = try #require(document["fragments"]?.arrayValue).compactMap(\.stringValue)
        return (fragments, try #require(document["expected"]))
    }

    @Test("Seven fragments emit /root, then each element when it is complete")
    func sevenFragments() throws {
        let (fragments, expected) = try ObjectModeTests.fragments()
        #expect(fragments.count == 7)
        var decoder = SpecStreamDecoder(mode: .object)
        var perPush: [[String]] = []
        var document: JSONValue = .object([:])
        for fragment in fragments {
            var paths: [String] = []
            for event in decoder.push(fragment) {
                guard case .patch(let patch) = event else {
                    Issue.record("unexpected \(event)")
                    continue
                }
                paths.append(patch.path)
                try document.apply(patch)
            }
            perPush.append(paths)
        }
        let flushed = decoder.flush()
        #expect(flushed.isEmpty)  // everything was complete by the last push
        // Order inside one push: /root, /state, then elements by id.
        #expect(
            perPush == [
                [], ["/root"], [], ["/elements/main"], [], ["/elements/t1"],
                ["/state", "/elements/t2"],
            ])
        #expect(document == expected)
        let decoded = try Spec.decode(Data(fragments.joined().utf8)).spec
        #expect(Spec.lenient(document).spec == decoded)
    }

    @Test("A changed element is emitted again, whole")
    func changedElement() {
        var decoder = SpecStreamDecoder(mode: .object)
        _ = decoder.push(#"{"elements":{"a":{"type":"Text","props":{"content":"x"}}"#)
        // A duplicate key later in the document changes the element.
        let events = decoder.push(#","a":{"type":"Text","props":{"content":"y"}}}}"#)
        #expect(
            events == [
                .patch(
                    SpecPatch(
                        op: .replace, path: "/elements/a",
                        value: ["type": "Text", "props": ["content": "y"]]))
            ])
    }

    @Test("An element without a type is never emitted")
    func noType() {
        var decoder = SpecStreamDecoder(mode: .object)
        var events = decoder.push(#"{"elements":{"a":{"props":{}},"b":{"type":"Te"#)
        events += decoder.push(#"xt"}"#)
        #expect(
            events == [.patch(SpecPatch(op: .add, path: "/elements/b", value: ["type": "Text"]))])
        events = decoder.push("}}")
        #expect(events.isEmpty)
        #expect(decoder.flush().isEmpty)
    }

    @Test("An unclosed document is used tolerantly at flush, with one journal entry")
    func unclosedAtFlush() {
        var decoder = SpecStreamDecoder(mode: .object)
        _ = decoder.push(#"{"root":"main","elements":{"main":{"type":"Card","props":{"title":"Hi"#)
        let flushed = decoder.flush()
        #expect(
            flushed == [
                .patch(
                    SpecPatch(
                        op: .add, path: "/elements/main",
                        value: ["type": "Card", "props": ["title": "Hi"]])),
                .error(.badLine(index: 0, reason: "document was not closed")),
            ])
    }

    @Test("Text that is not JSON gives one error at flush and no patches")
    func notJSON() {
        var decoder = SpecStreamDecoder(mode: .object)
        #expect(decoder.push("hello").isEmpty)
        #expect(decoder.flush() == [.error(.badLine(index: 0, reason: "invalid JSON"))])
    }
}
