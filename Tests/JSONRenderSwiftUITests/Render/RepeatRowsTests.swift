import JSONRenderCore
import JSONRenderSwiftUI
import Testing

@Suite struct RepeatRowsTests {
    @Test func flatIDsAreRowMajorAndKeyed() {
        let rows = JRRepeatRows(
            elementID: "list",
            scopes: [
                RepeatScope(item: "x", index: 0, basePath: "/a/0", key: "k1"),
                RepeatScope(item: "y", index: 1, basePath: "/a/1", key: "k2"),
            ],
            childIDs: ["t", "u"])
        #expect(rows.flatIDs.count == 4)
        #expect(rows.ids(forRow: 0) + rows.ids(forRow: 1) == rows.flatIDs)
        #expect(rows.ids(forRow: 0)[0].hasSuffix("k:k1\u{1F}t"))
        #expect(rows.ids(forRow: 5).isEmpty)
    }

    @Test func duplicateKeysFallBackToIndexIdentity() {
        let rows = JRRepeatRows(
            elementID: "list",
            scopes: [
                RepeatScope(item: "x", index: 0, basePath: "/a/0", key: "same"),
                RepeatScope(item: "y", index: 1, basePath: "/a/1", key: "same"),
            ],
            childIDs: ["t"])
        #expect(Set(rows.flatIDs).count == 2)
        #expect(rows.flatIDs.allSatisfy { $0.contains("i:") })
    }
}
