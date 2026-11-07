import CoreGraphics
import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderStandardCatalog

/// The pure rules behind Image, Avatar, Slider, Progress, ToggleGroup and Carousel.
@Suite struct ComponentLogicTests {
    /// A 1 × 1 PNG.
    static let pixelPNG =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="

    @Test func imageSourcesAreClassified() throws {
        #expect(JRImageSource(nil) == .none)
        #expect(JRImageSource("  ") == .none)
        #expect(JRImageSource("systemName:folder") == .symbol("folder"))
        #expect(
            JRImageSource("data:image/png;base64,AAAA") == .dataURI("data:image/png;base64,AAAA"))
        #expect(JRImageSource("/tmp/a.png") == .localFile(URL(fileURLWithPath: "/tmp/a.png")))
        #expect(JRImageSource("file:///tmp/a.png").isLocal)
        let remote = try #require(URL(string: "https://images.example.com/a.png"))
        #expect(JRImageSource("https://images.example.com/a.png") == .remote(remote))
        #expect(JRImageSource("http://example.com/a.png") == .unsupported(host: "example.com"))
        #expect(JRImageSource("relative/a.png") == .unsupported(host: nil))
    }

    @Test func dataURIsDecodeAndSVGIsRefused() async throws {
        let png = JRImageSource("data:image/png;base64," + Self.pixelPNG)
        let image = await JRImageDecoder.load(png, roots: [], maxPixel: 64)
        #expect(image?.width == 1)
        #expect(JRImageDecoder.dataURIBytes("data:image/svg+xml;base64,PHN2Zy8+") == nil)
        #expect(JRImageDecoder.dataURIBytes("data:image/png,raw") == nil)  // not base64
        #expect(JRImageDecoder.dataURIBytes("data:text/plain;base64,QQ==") == nil)
    }

    @Test func localFilesLoadOnlyInsideTheRoots() async throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("jr3b-images-\(UUID().uuidString)")
        let root = base.appendingPathComponent("root")
        let outside = base.appendingPathComponent("outside")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }
        let bytes = try #require(Data(base64Encoded: Self.pixelPNG))
        let inside = root.appendingPathComponent("a.png")
        let secret = outside.appendingPathComponent("b.png")
        try bytes.write(to: inside)
        try bytes.write(to: secret)
        let link = root.appendingPathComponent("escape.png")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: secret)

        #expect(await JRImageDecoder.load(.localFile(inside), roots: [root], maxPixel: 64) != nil)
        #expect(await JRImageDecoder.load(.localFile(inside), roots: [], maxPixel: 64) == nil)
        #expect(await JRImageDecoder.load(.localFile(secret), roots: [root], maxPixel: 64) == nil)
        #expect(await JRImageDecoder.load(.localFile(link), roots: [root], maxPixel: 64) == nil)
        let dotted = URL(fileURLWithPath: root.path + "/../outside/b.png")
        #expect(await JRImageDecoder.load(.localFile(dotted), roots: [root], maxPixel: 64) == nil)
    }

    @Test func imageSizesArePositive() {
        #expect(JRImageSize.points(nil) == nil)
        #expect(JRImageSize.points(-4) == nil)
        #expect(JRImageSize.points(.infinity) == nil)
        #expect(JRImageSize.points(120) == 120)
        #expect(JRImageSize.points(1e9) == 4096)
    }

    @Test func avatarInitialsFollowUpstream() {
        #expect(JRAvatarInitials.make("Ada Lovelace") == "AL")
        #expect(JRAvatarInitials.make("grace brewster hopper") == "GB")
        #expect(JRAvatarInitials.make("  ") == "?")
        #expect(JRAvatarInitials.make("") == "?")
    }

    @Test func sliderRangeAndStep() {
        #expect(JRSliderMath.range(min: nil, max: nil) == 0...100)
        #expect(JRSliderMath.range(min: 10, max: 5) == 10...11)
        #expect(JRSliderMath.range(min: .nan, max: 50) == 0...50)
        #expect(JRSliderMath.step(nil) == 1)
        #expect(JRSliderMath.step(-2) == 1)
        #expect(JRSliderMath.step(0.5) == 0.5)
        #expect(JRSliderMath.snap(23.4, range: 0...100, step: 5) == 25)
        #expect(JRSliderMath.snap(-3, range: 0...100, step: 1) == 0)
        #expect(JRSliderMath.snap(99.9, range: 1...50, step: 2) == 50)
    }

    @Test func progressClampsAndRounds() {
        #expect(JRProgressMeasure(value: 72, max: 100).percent == 72)
        #expect(JRProgressMeasure(value: 3, max: 8).percent == 38)
        #expect(JRProgressMeasure(value: 150, max: nil).value == 100)
        #expect(JRProgressMeasure(value: -5, max: 0).value == 0)
        #expect(JRProgressMeasure(value: .nan, max: 10).percent == 0)
    }

    @Test func toggleGroupValuesAreCommaStringsInItemOrder() {
        #expect(JRToggleGroupValue.decode("bold,,italic", type: .multiple) == ["bold", "italic"])
        #expect(JRToggleGroupValue.decode("bold,italic", type: .single) == ["bold,italic"])
        #expect(JRToggleGroupValue.decode("", type: .single).isEmpty)
        #expect(
            JRToggleGroupValue.encode(["italic", "bold"], order: ["bold", "italic", "under"])
                == "bold,italic")
    }

    @Test func carouselItemsDropEmptyEntries() {
        let items = JRCarouselItems.decode([
            ["title": "One", "description": .null], ["title": ""], ["description": "Two"], 5,
        ])
        #expect(items.map(\.title) == ["One", nil])
        #expect(items.map(\.description) == [nil, "Two"])
        #expect(items.map(\.id) == [0, 1])
    }

    @Test func optionsAreUnique() {
        #expect(StandardOptions.unique(["a", "b", "a"]) == ["a", "b"])
    }

    @Test @MainActor func remoteImageProviderDefaultsToNil() {
        #expect(EnvironmentValues().jrRemoteImageProvider == nil)
        #expect(EnvironmentValues().jrLocalImageRoots.isEmpty)
    }
}
