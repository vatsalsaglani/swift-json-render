import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderCharts

/// `Tests/ParityFixtures/charts/composite`: the site mocks of the five composite charts.
@Suite("Composite chart fixture specs")
@MainActor
struct CompositeFixtureTests {
    nonisolated static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("ParityFixtures/charts/composite")

    nonisolated static var files: [String] {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("index.json")),
            let json = try? JSONDecoder().decode(JSONValue.self, from: data),
            let rows = json["fixtures"]?.arrayValue
        else { return [] }
        return rows.compactMap { $0["file"]?.stringValue }
    }

    @Test("The index lists every fixture file, one per composite chart")
    func index() throws {
        let listed = Set(Self.files)
        let present = Set(
            try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
                .filter { $0.hasSuffix(".json") && $0 != "index.json" })
        #expect(listed.count == 5)
        #expect(listed == present)
    }

    @Test("Each fixture validates with no issue and renders", arguments: files)
    func validatesAndRenders(file: String) throws {
        let data = try Data(contentsOf: Self.folder.appendingPathComponent(file))
        let spec = try Spec.decode(data).spec
        let catalog = try Catalog.charts
        let report = catalog.validate(spec, options: ValidateSpecOptions(checkComponents: false))
        #expect(report.issues.isEmpty, "\(file): \(report.issues.map(\.message))")
        let charts = Set(ChartEntries.composite.map(\.name))
        var rendered = 0
        for id in spec.elements.keys.sorted() {
            guard let element = spec.elements[id], charts.contains(element.type),
                let factory = catalog.viewFactory(for: element.type)
            else { continue }
            var resolver = PropResolver(
                context: PropResolutionContext(
                    state: spec.state ?? .object([:]), functions: catalog.functions))
            let props = resolver.resolveProps(element.props)
            let bindings = resolver.bindings(in: element.props)
            let view = factory.make(JRRenderContext(id: id, props: props, bindings: bindings))
                .frame(width: 520)
            #expect(ImageRenderer(content: view).cgImage != nil, "\(file) \(id) did not render")
            rendered += 1
        }
        #expect(rendered == 1, "\(file)")
    }
}
