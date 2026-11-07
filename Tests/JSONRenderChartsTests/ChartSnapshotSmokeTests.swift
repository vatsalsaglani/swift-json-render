import AppKit
import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderCharts

/// Renders every chart variant offscreen in light and dark. A crash test, not a pixel
/// test. With `JR_CHART_SNAPSHOT_DIR` set, it also writes `<variant>-<scheme>.png` there.
@Suite("Chart snapshot smoke")
@MainActor
struct ChartSnapshotSmokeTests {
    @Test("Every variant renders in light and dark", arguments: ChartSamples.all)
    func renders(sample: ChartSamples.Sample) throws {
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
                try write(
                    image, to: directory,
                    name: "\(sample.name)-\(scheme == .dark ? "dark" : "light")")
            }
        }
    }

    private func write(_ image: CGImage, to directory: String, name: String) throws {
        let folder = URL(fileURLWithPath: directory, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let bitmap = NSBitmapImageRep(cgImage: image)
        let data = try #require(bitmap.representation(using: .png, properties: [:]))
        try data.write(to: folder.appendingPathComponent(name + ".png"))
    }
}
