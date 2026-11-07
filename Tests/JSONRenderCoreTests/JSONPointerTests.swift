import Foundation
import Testing

@testable import JSONRenderCore

@Suite("JSONPointer")
struct JSONPointerTests {
    /// `JSONPointer("literal")` is literal coercion (`init(stringLiteral:)`, never throws).
    /// Passing a `String` value selects the throwing parser.
    static func parse(_ string: String) throws(JSONPointerError) -> JSONPointer {
        try JSONPointer(string)
    }

    /// The RFC 6901 section 5 document.
    static let rfcDocument: JSONValue = [
        "foo": ["bar", "baz"], "": 0, "a/b": 1, "c%d": 2, "e^f": 3, "g|h": 4, "i\\j": 5,
        "k\"l": 6, " ": 7, "m~n": 8,
    ]

    @Test(
        "RFC 6901 section 5 vectors",
        arguments: [
            ("/foo", .array(["bar", "baz"])), ("/foo/0", "bar"), ("/a~1b", 1), ("/c%d", 2),
            ("/e^f", 3), ("/g|h", 4), ("/i\\j", 5), ("/k\"l", 6), ("/ ", 7), ("/m~0n", 8),
        ] as [(String, JSONValue)])
    func rfcVectors(_ pointer: String, _ expected: JSONValue) throws {
        #expect(Self.rfcDocument.value(at: try Self.parse(pointer)) == expected)
    }

    @Test("Root: \"\" and \"/\" are both the whole document (upstream leniency)")
    func root() throws {
        #expect(try Self.parse("").isRoot)
        #expect(try Self.parse("/").isRoot)
        #expect(Self.rfcDocument.value(at: try Self.parse("")) == Self.rfcDocument)
        // RFC 6901 reads "/" as the member "" (value 0). Upstream getByPath reads the root.
        #expect(Self.rfcDocument.value(at: try Self.parse("/")) == Self.rfcDocument)
        #expect(JSONPointer.root.description == "")
    }

    @Test("Escaping: ~1 unescapes before ~0, description escapes back")
    func escaping() throws {
        let pointer = try Self.parse("/a~0~1b/~01")
        #expect(pointer.tokens == ["a~/b", "~1"])
        #expect(pointer.description == "/a~0~1b/~01")
        #expect(JSONPointer(tokens: ["x/y", "m~n"]).description == "/x~1y/m~0n")
    }

    @Test("A pointer without a leading slash is accepted")
    func lenientLeadingSlash() throws {
        #expect(try Self.parse("user/name") == JSONPointer("/user/name"))
        #expect(try Self.parse("user").tokens == ["user"])
    }

    @Test("__proto__ is refused")
    func forbiddenToken() {
        #expect(throws: JSONPointerError.forbiddenToken("__proto__")) {
            try Self.parse("/__proto__/polluted")
        }
        let literal: JSONPointer = "/a/__proto__"
        #expect(literal.containsForbiddenToken)
        var state: JSONValue = [:]
        let wrote1 = state.set(true, at: literal)
        #expect(!wrote1)
        let wrote2 = state.add(true, at: literal)
        #expect(!wrote2)
        let wrote3 = state.remove(at: literal)
        #expect(!wrote3)
        #expect(state.value(at: literal) == nil)
        #expect(state == [:])
    }

    @Test("appending tokens, relative paths and indexes")
    func appending() throws {
        let base = try Self.parse("/groups/0")
        #expect(base.appending("a/b").description == "/groups/0/a~1b")
        #expect(base.appending(relative: "items").description == "/groups/0/items")
        #expect(base.appending(relative: "/items").description == "/groups/0/items")
        #expect(base.appending(relative: "user/name").description == "/groups/0/user/name")
        #expect(base.appending(relative: "") == base)
        #expect(base.appending(index: 3).description == "/groups/0/3")
        #expect(JSONPointer.root.appending(index: 2).description == "/2")
        #expect(base.parent?.description == "/groups")
        #expect(JSONPointer.root.parent == nil)
    }

    @Test("Codable writes the canonical string")
    func codable() throws {
        let pointer = try Self.parse("a~1b/c")
        let data = try JSONEncoder().encode([pointer])
        #expect(try JSONDecoder().decode(JSONValue.self, from: data) == ["/a~1b/c"])
        #expect(try JSONDecoder().decode([JSONPointer].self, from: data) == [pointer])
    }

    @Test("Array reads use JavaScript parseInt")
    func parseIntReads() {
        let value: JSONValue = ["items": [10, 20, 30]]
        #expect(value.value(at: "/items/1") == 20)
        #expect(value.value(at: "/items/01") == 20)
        #expect(value.value(at: "/items/1abc") == 20)
        #expect(value.value(at: "/items/-1") == nil)
        #expect(value.value(at: "/items/-") == nil)
        #expect(value.value(at: "/items/3") == nil)
        #expect(value.value(at: "/items/x") == nil)
    }

    @Test("Writes never leave holes and create intermediates by the next token")
    func writes() {
        var value: JSONValue = [:]
        let wrote4 = value.set("deep", at: "/a/0/b")
        #expect(wrote4)
        #expect(value == ["a": [["b": "deep"]]])
        let wrote5 = value.set(1, at: "/list/-")
        #expect(wrote5)
        #expect(value["list"] == [1])
        let wrote6 = value.set(1, at: "/list/5")
        #expect(!wrote6)
        let wrote7 = value.set(2, at: "/list/1")
        #expect(wrote7)
        #expect(value["list"] == [1, 2])
        let wrote8 = value.add(0, at: "/list/0")
        #expect(wrote8)
        #expect(value["list"] == [0, 1, 2])
        let wrote9 = value.set(1, at: JSONPointer.root)
        #expect(!wrote9)
        #expect(value.test([0, 1, 2], at: "/list"))
        #expect(!value.test([0, 1], at: "/list"))
    }
}
