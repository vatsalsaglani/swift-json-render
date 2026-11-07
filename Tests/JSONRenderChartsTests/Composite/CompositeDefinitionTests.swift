import AppKit
import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderCharts

@Suite("Composite chart definitions and registration")
struct CompositeDefinitionTests {
    static let names = ["Waterfall", "Funnel", "BoxPlot", "Candlestick", "Treemap"]

    @Test("The composite charts follow the mark charts, each with a renderer")
    func registered() throws {
        let catalog = try Catalog.charts
        #expect(ChartEntries.composite.map(\.name) == Self.names)
        #expect(Array(catalog.componentNames.suffix(Self.names.count)) == Self.names)
        for name in Self.names {
            #expect(catalog.viewFactory(for: name) != nil, "\(name) has no renderer")
        }
        #expect(catalog.ruleOrder.contains(CompositeChartRules.name))
        #expect(ChartEntries.components.count == 15)
    }

    @Test("Every definition has a description, unique props, the chrome and no children")
    func shape() {
        for definition in ChartEntries.composite {
            #expect(!definition.description.isEmpty, "\(definition.name)")
            guard case .object(let fields) = definition.props.kind else {
                Issue.record("\(definition.name) props are not an object")
                continue
            }
            let names = fields.map(\.name)
            #expect(Set(names).count == names.count, "\(definition.name) repeats a prop")
            for prop in ["data", "summary", "title", "caption", "height", "format"] {
                #expect(names.contains(prop), "\(definition.name) has no \(prop)")
            }
            #expect(definition.slots.contains("title"), "\(definition.name)")
            #expect(!definition.props.formatted().isEmpty)
            #expect(!definition.acceptsChildren, "\(definition.name): a chart has no children")
        }
    }

    @Test("Each example validates with no issue")
    func examples() throws {
        let catalog = try Catalog.charts
        for definition in ChartEntries.composite {
            let spec = Spec(
                root: "c",
                elements: ["c": UIElement(type: definition.name, props: definition.example ?? [:])])
            let report = catalog.validate(spec)
            #expect(report.valid, "\(definition.name): \(report.issues.map(\.message))")
            #expect(report.issues.isEmpty, "\(definition.name): \(report.issues.map(\.message))")
        }
    }

    @Test("Composite rules: positive and negative cases")
    func rules() {
        func texts(_ type: String, _ props: [String: JSONValue], _ rows: [JSONValue]) -> [String] {
            CompositeChartRules.check(type: type, props: props, rows: rows).map(\.1)
        }
        #expect(texts("Treemap", [:], [["value": 1]]).isEmpty)
        #expect(!texts("Treemap", [:], [["value": 0]]).isEmpty)
        #expect(
            !texts("BoxPlot", [:], [["min": 1, "q1": 3, "median": 2, "q3": 4, "max": 5]]).isEmpty)
        #expect(
            texts("BoxPlot", [:], [["min": 1, "q1": 2, "median": 3, "q3": 4, "max": 5]]).isEmpty)
        #expect(
            !texts("Candlestick", [:], [["open": 9, "high": 5, "low": 1, "close": 2]]).isEmpty)
        #expect(texts("Candlestick", [:], [["open": 3, "high": 5, "low": 1, "close": 2]]).isEmpty)
        let warning = CompositeChartRules.check(
            type: "Waterfall", props: ["subtotals": ["End"]], rows: [["label": "a", "value": 1]])
        #expect(warning.first?.0 == .warning)
        #expect(
            texts("Waterfall", ["subtotals": ["a"]], [["label": "a", "value": 1]]).isEmpty)
    }

    @Test("Default summaries name the chart and the largest value")
    func summaries() {
        let (funnel, _) = FunnelData.make(
            props: ["data": .some(CompositeSamples.stages), "label": "stage", "value": "n"])
        let text = ChartSummary.text(for: funnel, locale: Locale(identifier: "en_US"))
        #expect(text.hasPrefix("Funnel chart, 4 stages"))
        #expect(text.contains("Collected"))
    }
}

/// Renders every composite variant offscreen in light and dark. A crash test, not a pixel
/// test. With `JR_CHART_SNAPSHOT_DIR` set, it also writes `<variant>-<scheme>.png` there.
@Suite("Composite chart snapshot smoke")
@MainActor
struct CompositeSnapshotSmokeTests {
    @Test("Every composite variant renders in light and dark", arguments: CompositeSamples.all)
    func renders(sample: CompositeSamples.Sample) throws {
        let catalog = try Catalog.charts
        let factory = try #require(catalog.viewFactory(for: sample.type))
        for scheme in [ColorScheme.light, .dark] {
            let context = JRRenderContext(
                id: sample.name, props: sample.props.mapValues { Optional($0) },
                bindings: ["selection": JSONPointer(tokens: ["picked"])])
            let view = factory.make(context)
                .padding(16)
                .frame(width: 560)
                .background(JSONRenderTheme.native.color.surface)
                .environment(\.colorScheme, scheme)
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try #require(renderer.cgImage, "\(sample.name) did not render")
            #expect(image.width > 0 && image.height > 0)
            if let directory = ProcessInfo.processInfo.environment["JR_CHART_SNAPSHOT_DIR"] {
                let folder = URL(fileURLWithPath: directory, isDirectory: true)
                try FileManager.default.createDirectory(
                    at: folder, withIntermediateDirectories: true)
                let data = try #require(
                    NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
                try data.write(
                    to: folder.appendingPathComponent(
                        "\(sample.name)-\(scheme == .dark ? "dark" : "light").png"))
            }
        }
    }
}
