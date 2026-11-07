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
}
