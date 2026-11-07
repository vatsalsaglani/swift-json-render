// Owner: jr-3b. Image (every source and remote state), Avatar and Carousel.
import CoreGraphics
import Foundation
import JSONRenderSwiftUI
import Observation
import SwiftUI

struct MediaPage: GalleryPage {
    static let title = "Image, Avatar and Carousel"
    static let group = GalleryGroup.inputs

    @State private var provider = GalleryImageProvider()

    var body: some View {
        GalleryPageLayout(
            title: Self.title,
            note:
                "The package never fetches. An https image asks the host's provider; without one it stays a placeholder."
        ) {
            SpecExample(
                "Local sources",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"md","align":"start"},"children":["data","sym","none","http"]},
                      "data":{"type":"Image","props":{"alt":"Landscape","width":120,"height":80,"fit":"cover",
                        "src":"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADAAAAAgCAIAAADbtmxLAAAAV0lEQVR42u3VsREAEBBE0StQLWKVKEIdEk0oQgWERoKEDf7ML+Alt2cpV6kMECB1UCtu7jNo0ZyY7LFmawIESBgkd2WKO8TrAARogEL0UgECBAgQIECXddYi4g3XbT9lAAAAAElFTkSuQmCC"}},
                      "sym":{"type":"Image","props":{"alt":"Folder","src":"systemName:folder","width":32,"height":32}},
                      "none":{"type":"Image","props":{"alt":"Diagram","width":120,"height":80}},
                      "http":{"type":"Image","props":{"alt":"Logo","src":"http://example.com/logo.png","width":160,"height":80}}}}
                    """#)
            SpecExample(
                "https without a provider",
                json: #"""
                    {"root":"i","elements":{
                      "i":{"type":"Image","props":{"alt":"Build graph","src":"https://raw.githubusercontent.com/o/r/graph.png","width":220,"height":90}}}}
                    """#)
            SpecExample(
                "https through a host provider",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Grid","props":{"columns":3,"gap":"md"},"children":["ask","off","load","ok","fail","failslot"]},
                      "ask":{"type":"Image","props":{"alt":"Build graph","src":"https://ask.example.com/graph.png","width":200,"height":110}},
                      "off":{"type":"Image","props":{"alt":"Team photo","src":"https://off.example.com/team.png","width":200,"height":110}},
                      "load":{"type":"Image","props":{"alt":"Chart","src":"https://loading.example.com/c.png","width":200,"height":110}},
                      "ok":{"type":"Image","props":{"alt":"Landscape","src":"https://ok.example.com/l.png","width":200,"height":110,"fit":"cover"}},
                      "fail":{"type":"Image","props":{"alt":"Map","src":"https://fail.example.com/map.png","width":200,"height":110}},
                      "failslot":{"type":"Image","props":{"alt":"Map","src":"https://fail.example.com/map2.png","width":200,"height":110},"slots":{"error":["msg"]}},
                      "msg":{"type":"Alert","props":{"title":"Map unavailable","message":"The host refused the request.","type":"warning"}}}}
                    """#
            )
            .environment(\.jrRemoteImageProvider, provider)
            SpecExample(
                "Avatars",
                json: #"""
                    {"root":"s","elements":{
                      "s":{"type":"Stack","props":{"direction":"horizontal","gap":"md","align":"center"},"children":["a","b","c","d"]},
                      "a":{"type":"Avatar","props":{"name":"Ada Lovelace","size":"sm"}},
                      "b":{"type":"Avatar","props":{"name":"Grace Hopper"}},
                      "c":{"type":"Avatar","props":{"name":"Katherine Johnson","size":"lg"}},
                      "d":{"type":"Avatar","props":{"name":"Build bot","src":"systemName:gearshape","size":"lg"}}}}
                    """#)
            SpecExample(
                "Carousel",
                json: #"""
                    {"root":"c","elements":{
                      "c":{"type":"Carousel","props":{"items":[
                        {"title":"Streaming","description":"Patches apply as they arrive; the layout holds."},
                        {"title":"Nesting","description":"Card, Tabs and Table with row scopes."},
                        {"title":"Themes","description":"Native and high-contrast presets."},
                        {"title":"Forms","description":"Checks on blur, one primary action."}]}}}}
                    """#)
        }
    }
}

/// A demo provider: the URL host picks the state. It fetches nothing.
@MainActor
@Observable
final class GalleryImageProvider: JRRemoteImageProvider {
    private(set) var revision = 0
    private var allowed: Set<String> = []
    @ObservationIgnored private let picture = GalleryImageProvider.makePicture()

    func state(for url: URL, pixelSize: CGSize, elementID: String) -> JRRemoteImageState {
        let host = url.host() ?? ""
        switch host {
        case "off.example.com": return .notAllowed(reason: "Images from the web are off in Settings")
        case "loading.example.com": return .loading
        case "fail.example.com": return .failed("Image did not load")
        case "ok.example.com": return picture.map { .image($0) } ?? .failed("No picture")
        default:
            if allowed.contains(host) { return picture.map { .image($0) } ?? .loading }
            return .needsConsent(host: host)
        }
    }

    func requestConsent(for url: URL, elementID: String) {
        if let host = url.host() { allowed.insert(host) }
        revision += 1
    }

    /// A quiet two-band landscape, drawn once.
    private static func makePicture() -> CGImage? {
        let width = 240
        let height = 140
        guard
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.setFillColor(CGColor(red: 0.67, green: 0.77, blue: 0.87, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.47, green: 0.59, blue: 0.43, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: 52))
        context.setFillColor(CGColor(red: 0.95, green: 0.79, blue: 0.30, alpha: 1))
        context.fillEllipse(in: CGRect(x: 160, y: 84, width: 30, height: 30))
        return context.makeImage()
    }
}
