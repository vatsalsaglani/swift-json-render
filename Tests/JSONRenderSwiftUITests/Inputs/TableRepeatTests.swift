import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import Testing

@testable import JSONRenderStandardCatalog

/// Table rows from `rows` and from `repeat`, sorting and number columns.
@MainActor
@Suite struct TableRepeatTests {
    static let filesSpec = #"""
        {"root":"table","state":{"files":[
            {"path":"a.swift","added":12},{"path":"b.swift","added":3},{"path":"c.swift","added":40}]},
         "elements":{
          "table":{"type":"Table","props":{"columns":[{"key":"path","label":"File"},"added"],"rows":[]},
                   "repeat":{"statePath":"/files"},"children":["del"]},
          "del":{"type":"Button","props":{"label":"Remove"},
                 "on":{"press":{"action":"removeState","params":{"statePath":"/files","index":{"$index":true}}}}}}}
        """#

    private func rows(_ model: RenderModel) -> JRRepeatRows {
        let scopes = model.walk().elements.filter { $0.id == "del" }.compactMap(\.scope)
        return JRRepeatRows(elementID: "table", scopes: scopes, childIDs: ["del"])
    }

    @Test func repeatRowsBecomeTableRowsWithChildrenUnderTheRowScope() throws {
        let spec = try Spec.decode(Data(Self.filesSpec.utf8)).spec
        let model = RenderModel(spec: spec, catalog: try .standard)
        let repeatRows = rows(model)
        #expect(repeatRows.scopes.map(\.index) == [0, 1, 2])
        let table = JRTableModel(
            columns: [["key": "path", "label": "File"], "added"], rows: [], repeatRows: repeatRows)
        #expect(table.columns.map(\.label) == ["File", "added"])
        #expect(table.columns.map(\.isNumeric) == [false, true])
        #expect(
            table.rows.map(\.cells) == [["a.swift", "12"], ["b.swift", "3"], ["c.swift", "40"]])
        #expect(table.rows[1].childIDs == repeatRows.ids(forRow: 1))
        #expect(model.walk().fallbacks.isEmpty)
    }

    @Test func removeStateWithIndexRemovesTheRightRow() async throws {
        let spec = try Spec.decode(Data(Self.filesSpec.utf8)).spec
        let model = RenderModel(spec: spec, catalog: try .standard)
        let scope = try #require(rows(model).scopes.first { $0.index == 1 })
        await model.emit(id: "del", event: "press", scope: scope).value
        let files = await model.store.snapshot.state["files"]
        #expect(
            files?.arrayValue?.compactMap { $0["path"]?.stringValue } == ["a.swift", "c.swift"])
    }

    @Test func literalRowsAreTwoDimensionalStrings() {
        let table = JRTableModel(
            columns: ["Service", "Latency", "Uptime", "Service"],
            rows: [["API", "12ms", "99.99%"], ["DB", .number(145), .null], "odd"],
            repeatRows: nil)
        #expect(table.columns.map(\.key) == ["Service", "Latency", "Uptime"])  // duplicate dropped
        #expect(
            table.rows.map(\.cells) == [["API", "12ms", "99.99%"], ["DB", "145", ""], ["odd"]])
        // "12ms" is text, so Latency is not a number column; Uptime is.
        #expect(table.columns.map(\.isNumeric) == [false, false, true])
    }

    @Test func objectRowsReadColumnKeys() {
        let table = JRTableModel(
            columns: [
                ["key": "n", "label": "Name"], ["key": "v", "label": "Value", "align": "right"],
            ],
            rows: [["n": "x", "v": "a"]], repeatRows: nil)
        #expect(table.rows[0].cells == ["x", "a"])
        #expect(table.columns[1].isNumeric)  // align: right
    }

    @Test func numbersParseLikeTheyRead() {
        #expect(JRTableModel.number("1,284") == 1284)
        #expect(JRTableModel.number("99.9%") == 99.9)
        #expect(JRTableModel.number("-3") == -3)
        #expect(JRTableModel.number("$12.50") == 12.5)
        #expect(JRTableModel.number("12ms") == nil)
        #expect(JRTableModel.number("") == nil)
        #expect(JRTableModel.number("1e5") == nil)
    }

    @Test func sortIsStableNumericAndTextual() {
        let table = JRTableModel(
            columns: ["name", "n"],
            rows: [["b", "10"], ["a", "9"], ["c", "10"]], repeatRows: nil)
        let byNumber = table.sorted(by: JRTableSort(column: "n", ascending: true))
        #expect(byNumber.map { $0.cells[0] } == ["a", "b", "c"])
        let byNumberDown = table.sorted(by: JRTableSort(column: "n", ascending: false))
        #expect(byNumberDown.map { $0.cells[0] } == ["b", "c", "a"])
        let byName = table.sorted(by: JRTableSort(column: "name", ascending: true))
        #expect(byName.map { $0.cells[0] } == ["a", "b", "c"])
        #expect(table.sorted(by: nil) == table.rows)
        #expect(table.sorted(by: JRTableSort(column: "missing", ascending: true)) == table.rows)
    }
}
