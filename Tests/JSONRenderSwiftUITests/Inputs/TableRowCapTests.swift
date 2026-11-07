import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import Testing

@testable import JSONRenderStandardCatalog

/// jr-2p item 11: literal rows past `maxRepeatRows` are not drawn.
@MainActor
@Suite struct TableRowCapTests {
    static func literalRows(_ count: Int) -> [JSONValue] {
        (0..<count).map { .array([.string("r\($0)"), .number(Double($0))]) }
    }

    @Test func literalRowsAreCappedAtTheRepeatLimit() {
        let table = JRTableModel(
            columns: ["Name", "Value"], rows: Self.literalRows(1_200), repeatRows: nil)
        #expect(table.rows.count == 500)
        #expect(table.totalRows == 1_200)
        #expect(table.isTruncated)
        #expect(table.rows.last?.cells == ["r499", "499"])
        #expect(table.footer == "Showing 500 of 1200 rows")
        #expect(table.columns.map(\.isNumeric) == [false, true])
    }

    @Test func aSmallerLimitFromTheSpecApplies() {
        let table = JRTableModel(
            columns: ["Name"], rows: Self.literalRows(30), repeatRows: nil, maxRows: 10)
        #expect(table.rows.count == 10)
        #expect(table.footer == "Showing 10 of 30 rows")
    }

    @Test func rowsWithinTheLimitHaveNoFooter() {
        let table = JRTableModel(
            columns: ["Name"], rows: Self.literalRows(500), repeatRows: nil)
        #expect(table.rows.count == 500)
        #expect(!table.isTruncated)
        #expect(table.footer == nil)
    }

    @Test func repeatRowsAreUnchanged() {
        let scopes = (0..<3).map {
            RepeatScope(
                item: ["n": .number(Double($0))], index: $0,
                basePath: JSONPointer(tokens: ["rows", String($0)]))
        }
        let repeatRows = JRRepeatRows(elementID: "t", scopes: scopes, childIDs: [])
        let table = JRTableModel(
            columns: ["n"], rows: Self.literalRows(1_200), repeatRows: repeatRows)
        #expect(table.rows.map(\.cells) == [["0"], ["1"], ["2"]])
        #expect(table.totalRows == 3)
        #expect(table.footer == nil)
    }
}
