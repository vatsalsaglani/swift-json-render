import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderCharts

/// `Tests/ParityFixtures/charts`: the site mocks and the VPLAN §7.3 example as specs.
@Suite("Chart fixture specs")
@MainActor
struct ChartFixtureTests {
    nonisolated static let folder = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("ParityFixtures/charts")

    nonisolated static var files: [String] {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("index.json")),
            let json = try? JSONDecoder().decode(JSONValue.self, from: data),
            let rows = json["fixtures"]?.arrayValue
        else { return [] }
        return rows.compactMap { $0["file"]?.stringValue }
    }

    @Test("The index lists every fixture file")
    func index() throws {
        let listed = Set(Self.files)
        let present = Set(
            try FileManager.default.contentsOfDirectory(atPath: Self.folder.path)
                .filter { $0.hasSuffix(".json") && $0 != "index.json" })
        #expect(!listed.isEmpty)
        #expect(listed == present)
    }

    @Test("Each fixture validates with no chart error and renders", arguments: files)
    func validatesAndRenders(file: String) throws {
        let data = try Data(contentsOf: Self.folder.appendingPathComponent(file))
        let spec = try Spec.decode(data).spec
        let catalog = try Catalog.charts
        let report = catalog.validate(spec, options: ValidateSpecOptions(checkComponents: false))
        #expect(report.errors.isEmpty, "\(file): \(report.errors.map(\.message))")
        let charts = Set(ChartKind.allCases.map(\.rawValue))
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
            let image = ImageRenderer(content: view).cgImage
            #expect(image != nil, "\(file) \(id) did not render")
        }
    }
}
