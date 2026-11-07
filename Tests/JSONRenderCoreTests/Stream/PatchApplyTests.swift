import Testing

@testable import JSONRenderCore

@Suite("Patch application")
struct PatchApplyTests {
    static func applied(_ document: JSONValue, _ patches: SpecPatch...) throws(StreamError)
        -> JSONValue
    {
        var document = document
        for (index, patch) in patches.enumerated() { try document.apply(patch, index: index) }
        return document
    }

    static func failure(_ document: JSONValue, _ patch: SpecPatch) -> String? {
        var document = document
        do {
            try document.apply(patch)
            return nil
        } catch {
            guard case .patchFailed(_, _, _, let reason) = error else { return "\(error)" }
            return reason
        }
    }

    @Test("add: object member, array insert, append, index past the end refused")
    func add() throws {
        #expect(try Self.applied([:], .init(op: .add, path: "/a", value: 1)) == ["a": 1])
        #expect(
            try Self.applied(["l": [1, 3]], .init(op: .add, path: "/l/1", value: 2)) == [
                "l": [1, 2, 3]
            ])
        #expect(
            try Self.applied(["l": [1]], .init(op: .add, path: "/l/-", value: 2)) == ["l": [1, 2]])
        #expect(
            try Self.applied(["l": [1]], .init(op: .add, path: "/l/1", value: 2)) == ["l": [1, 2]])
        #expect(Self.failure(["l": [1]], .init(op: .add, path: "/l/5", value: 2)) == "refused")
        #expect(
            try Self.applied([:], .init(op: .add, path: "/a/b/-", value: 1)) == ["a": ["b": [1]]])
    }

    @Test("replace: sets in place, and sets an absent target (streaming tolerance)")
    func replace() throws {
        #expect(
            try Self.applied(["l": [1, 2]], .init(op: .replace, path: "/l/0", value: 9)) == [
                "l": [9, 2]
            ])
        #expect(try Self.applied([:], .init(op: .replace, path: "/x", value: 1)) == ["x": 1])
    }

    @Test("remove: present and absent")
    func remove() throws {
        #expect(try Self.applied(["a": 1, "b": 2], .init(op: .remove, path: "/a")) == ["b": 2])
        #expect(try Self.applied(["l": [1, 2]], .init(op: .remove, path: "/l/0")) == ["l": [2]])
        #expect(try Self.applied(["a": 1], .init(op: .remove, path: "/zz")) == ["a": 1])
    }

    @Test("move and copy, with and without from")
    func moveCopy() throws {
        #expect(try Self.applied(["a": 1], .init(op: .move, path: "/b", from: "/a")) == ["b": 1])
        #expect(
            try Self.applied(["a": 1], .init(op: .copy, path: "/b", from: "/a")) == [
                "a": 1, "b": 1,
            ])
        #expect(try Self.applied(["a": 1], .init(op: .move, path: "/b")) == ["a": 1])
        #expect(try Self.applied(["a": 1], .init(op: .copy, path: "/b")) == ["a": 1])
        #expect(
            try Self.applied(["l": [1, 2, 3]], .init(op: .move, path: "/l/0", from: "/l/2"))
                == ["l": [3, 1, 2]])
    }

    @Test("test: deep equality; a mismatch throws with the index")
    func test() throws {
        #expect(
            try Self.applied(["a": ["b": [1]]], .init(op: .test, path: "/a", value: ["b": [1]]))
                == ["a": ["b": [1]]])
        var document: JSONValue = ["a": 1]
        #expect(
            throws: StreamError.patchFailed(
                index: 4, op: .test, path: "/a", reason: "test mismatch")
        ) {
            try document.apply(SpecPatch(op: .test, path: "/a", value: 2), index: 4)
        }
        // An absent `value` is undefined: it matches an absent path only.
        #expect(try Self.applied(["a": 1], .init(op: .test, path: "/zz")) == ["a": 1])
        #expect(Self.failure(["a": 1], .init(op: .test, path: "/a")) == "test mismatch")
    }

    @Test("value nil (undefined): deletes an object member, refused in an array")
    func undefinedValue() throws {
        #expect(try Self.applied(["a": 1, "b": 2], .init(op: .add, path: "/a")) == ["b": 2])
        #expect(try Self.applied(["a": 1], .init(op: .replace, path: "/a")) == [:])
        #expect(
            Self.failure(["l": [1]], .init(op: .add, path: "/l/0")) == "undefined value in array")
        #expect(
            Self.failure(["l": [1]], .init(op: .replace, path: "/l/-"))
                == "undefined value in array")
        // `"value": null` is JSON null, not undefined.
        #expect(try Self.applied([:], .init(op: .add, path: "/a", value: .null)) == ["a": nil])
    }

    @Test("Pointer escaping ~0 and ~1")
    func escaping() throws {
        #expect(try Self.applied([:], .init(op: .add, path: "/a~1b", value: 1)) == ["a/b": 1])
        #expect(try Self.applied([:], .init(op: .add, path: "/m~0n", value: 1)) == ["m~n": 1])
    }

    @Test("__proto__, the root pointer and a too-deep write are refused")
    func refused() {
        #expect(
            Self.failure([:], .init(op: .add, path: "/__proto__/x", value: 1)) == "invalid path")
        #expect(
            Self.failure(["a": 1], .init(op: .copy, path: "/b", from: "/__proto__"))
                == "invalid path")
        #expect(Self.failure([:], .init(op: .add, path: "", value: 1)) == "invalid path")
        #expect(Self.failure([:], .init(op: .remove, path: "/")) == "invalid path")
        var deep: JSONValue = 1
        for _ in 0..<JSONValue.maxDecodeDepth { deep = [deep] }
        #expect(Self.failure([:], .init(op: .add, path: "/a", value: deep)) == "too deep")
        var fits: JSONValue = 1
        for _ in 0..<(JSONValue.maxDecodeDepth - 1) { fits = [fits] }
        #expect(Self.failure([:], .init(op: .add, path: "/a", value: fits)) == nil)
    }
}
