import CoreGraphics
import JSONRenderCore
import JSONRenderSwiftUI
import Testing

@testable import JSONRenderCharts

@Suite("Selection write-back")
@MainActor
struct SelectionTests {
    final class Recorder {
        var writes: [(JSONPointer, JSONValue)] = []
    }

    func writer(_ recorder: Recorder) -> JRBindingWriter {
        JRBindingWriter { pointer, value in recorder.writes.append((pointer, value)) }
    }

    @Test("The selected category is written to the bound pointer")
    func category() {
        let (data, _) = ChartData.make(
            props: ["data": ChartDataTests.runs, "x": "run", "y": "n"], kind: .bar)
        let recorder = Recorder()
        let pointer = JSONPointer(tokens: ["picked"])
        ChartSelection.write(
            "4209", data: data, bindings: ["selection": pointer], writer: writer(recorder))
        #expect(recorder.writes.count == 1)
        #expect(recorder.writes.first?.0 == pointer)
        #expect(recorder.writes.first?.1 == "4209")
        ChartSelection.write(
            nil, data: data, bindings: ["selection": pointer], writer: writer(recorder))
        #expect(recorder.writes.last?.1 == .null)
    }

    @Test("A numeric axis writes the number")
    func number() {
        let (data, _) = ChartData.make(
            props: ["data": [["t": 1, "v": 2], ["t": 2, "v": 3]], "x": "t", "y": "v"], kind: .line)
        #expect(data.xAxis == .number)
        #expect(ChartSelection.value(for: "2", in: data) == 2)
    }

    @Test("Nothing is written without a binding")
    func unbound() {
        let (data, _) = ChartData.make(props: ["data": ChartDataTests.runs], kind: .bar)
        let recorder = Recorder()
        ChartSelection.write("a", data: data, bindings: [:], writer: writer(recorder))
        #expect(recorder.writes.isEmpty)
    }

    @Test("Arrow keys move through the labels and wrap")
    func move() {
        let labels = ["a", "b", "c"]
        #expect(ChartSelection.move(from: nil, by: 1, in: labels) == "a")
        #expect(ChartSelection.move(from: nil, by: -1, in: labels) == "c")
        #expect(ChartSelection.move(from: "b", by: 1, in: labels) == "c")
        #expect(ChartSelection.move(from: "c", by: 1, in: labels) == "a")
        #expect(ChartSelection.move(from: "a", by: -1, in: labels) == "c")
        #expect(ChartSelection.move(from: "x", by: 1, in: []) == nil)
    }

    @Test("A date selection snaps to the nearest point")
    func nearest() {
        let (data, _) = ChartData.make(
            props: [
                "data": [["d": "2026-11-05", "v": 1], ["d": "2026-11-07", "v": 2]], "x": "d",
                "y": "v",
            ], kind: .line)
        let late = data.points[1].x.numeric ?? 0
        #expect(ChartSelection.nearestLabel(to: late - 3_600, in: data) == "2026-11-07")
    }

    /// Drives the selection state the way the chart does and records the writes.
    func perform(
        _ write: String??, data: ChartData, recorder: Recorder
    ) {
        guard case .some(let value) = write else { return }
        ChartSelection.write(
            value, data: data, bindings: ["selection": JSONPointer(tokens: ["picked"])],
            writer: writer(recorder))
    }

    @Test("Hover never writes to state; it only moves the highlight")
    func hoverDoesNotWrite() {
        var state = ChartSelectionState()
        state.hover("4209")
        #expect(state.shown == "4209")
        state.hover(nil)
        #expect(state.shown == nil)
        #expect(state.committed == nil)
    }

    @Test("A click writes; a second click on the same mark writes null")
    func clickWrites() {
        let (data, _) = ChartData.make(
            props: ["data": ChartDataTests.runs, "x": "run", "y": "n"], kind: .bar)
        let recorder = Recorder()
        var state = ChartSelectionState()
        state.hover("4208")
        perform(state.click("4209"), data: data, recorder: recorder)
        #expect(recorder.writes.map(\.1) == ["4209"])
        state.hover("4210")
        #expect(state.shown == "4210")
        state.hover(nil)
        #expect(state.shown == "4209")
        perform(state.click("4209"), data: data, recorder: recorder)
        #expect(recorder.writes.map(\.1) == ["4209", .null])
        #expect(state.committed == nil)
        perform(state.click(nil), data: data, recorder: recorder)
        #expect(recorder.writes.count == 2)
    }

    @Test("Arrow keys and Escape write; Escape with nothing selected does not")
    func keysWrite() {
        let (data, _) = ChartData.make(
            props: ["data": ChartDataTests.runs, "x": "run", "y": "n"], kind: .bar)
        let recorder = Recorder()
        var state = ChartSelectionState()
        perform(state.clear(), data: data, recorder: recorder)
        #expect(recorder.writes.isEmpty)
        perform(state.move(by: 1, in: data.categories), data: data, recorder: recorder)
        perform(state.move(by: 1, in: data.categories), data: data, recorder: recorder)
        #expect(recorder.writes.map(\.1) == ["4208", "4209"])
        perform(state.clear(), data: data, recorder: recorder)
        #expect(recorder.writes.last?.1 == .null)
    }

    @Test("A state change syncs without a write")
    func syncFromState() {
        var state = ChartSelectionState()
        state.sync(fromState: "4210")
        #expect(state.committed == "4210")
        #expect(state.shown == "4210")
    }

    @Test("Pie slices by fraction of the turn")
    func slices() {
        let (data, _) = ChartData.make(
            props: [
                "data": [["l": "a", "v": 3], ["l": "b", "v": 1]], "label": "l", "value": "v",
            ], kind: .pie)
        #expect(ChartSelection.slice(atFraction: 0.1, in: data) == "a")
        #expect(ChartSelection.slice(atFraction: 0.8, in: data) == "b")
    }

    @Test("A donut's hole selects nothing; a pie's centre selects a slice")
    @MainActor
    func donutHole() {
        let rows: JSONValue = [["l": "a", "v": 3], ["l": "b", "v": 1]]
        let (pie, _) = ChartData.make(
            props: ["data": rows, "label": "l", "value": "v"], kind: .pie)
        let (donut, _) = ChartData.make(
            props: ["data": rows, "label": "l", "value": "v", "donut": true], kind: .pie)
        #expect(donut.options.donut)
        let frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        let ratio = ChartPointer.donutInnerRatio
        func label(_ data: ChartData, _ point: CGPoint) -> String? {
            ChartPointer.sliceLabel(
                at: point, in: frame, data: data, innerRatio: data.options.donut ? ratio : 0)
        }
        // The centre, 0.5 R and 0.8 R straight up (12 o'clock: the first slice).
        let centre = CGPoint(x: 100, y: 100)
        let half = CGPoint(x: 100, y: 50)
        let outer = CGPoint(x: 100, y: 20)
        #expect(label(donut, centre) == nil)
        #expect(label(donut, half) == nil)
        #expect(label(donut, outer) == "a")
        #expect(label(pie, centre) != nil)
        #expect(label(pie, half) == "a")
        #expect(label(pie, outer) == "a")
        // Outside the outer radius: nothing.
        #expect(label(pie, CGPoint(x: 199, y: 1)) == nil)
    }

    @Test("The index axis reads the label at the rounded index")
    @MainActor
    func indexAxis() {
        var data = ChartData(kind: .candlestick)
        data.categories = ["Mon", "Tue", "Wed"]
        #expect(ChartPointer.indexLabel(0.4, in: data) == "Mon")
        #expect(ChartPointer.indexLabel(1.6, in: data) == "Wed")
        #expect(ChartPointer.indexLabel(-0.6, in: data) == nil)
        #expect(ChartPointer.indexLabel(2.6, in: data) == nil)
        #expect(ChartPointer.indexLabel(nil, in: data) == nil)
        #expect(ChartPointer.indexLabel(.nan, in: data) == nil)
    }

    @Test("Candlestick categories are the period labels the index axis reads")
    func candlestickCategories() {
        let rows: JSONValue = [
            ["d": "a", "open": 1, "high": 3, "low": 0, "close": 2],
            ["d": "b", "open": 2, "high": 4, "low": 1, "close": 3],
            ["d": "bad", "open": 2],
        ]
        let (data, _) = CandlestickData.make(props: ["data": rows, "x": "d"])
        #expect(data.categories == ["a", "b"])
        #expect(CandlestickData.periods(in: data).map(\.label) == data.categories)
    }
}
