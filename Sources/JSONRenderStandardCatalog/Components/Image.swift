// Owner: jr-3b (wave 2). Image: a picture from a data URI, an allowed local file, an SF
// Symbol, or (through the host's provider) an https URL. The package never fetches.
public import CoreGraphics
public import Foundation
internal import ImageIO
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

extension EnvironmentValues {
    /// Folders the standard Image and Avatar may read local files from. Default: none, so
    /// a local path draws a placeholder. A file must be inside a root after symbolic links
    /// are resolved.
    @Entry public var jrLocalImageRoots: [URL] = []
}

/// The `fit` prop.
public enum JRImageFit: String, Sendable, CaseIterable {
    /// The whole image inside the frame (the default).
    case contain
    /// The frame filled; the image is cropped.
    case cover
}

/// What an image style draws.
public enum JRImageContent {
    /// The decoded picture.
    case image(Image)
    /// An SF Symbol (`src: "systemName:<name>"`).
    case symbol(String)
    /// No picture: the alt text and an optional note (for example "Image from
    /// example.com").
    case placeholder(note: String?)
    /// An https image the user has not allowed yet. `allow` asks the host for consent.
    case needsConsent(host: String, allow: @MainActor () -> Void)
    /// The host is loading it. The `loading` slot, when the spec fills it.
    case loading(JRStyleContent?)
    /// The host could not load it. The `error` slot, when the spec fills it.
    case failed(message: String, JRStyleContent?)
}

/// What an image style receives. `width` and `height` are the spec's size in points.
public struct JRImageStyleConfiguration {
    public let alt: String
    public let content: JRImageContent
    public let width: CGFloat?
    public let height: CGFloat?
    public let fit: JRImageFit
    public let theme: JSONRenderTheme
}

/// Restyles every Image in a subtree.
public protocol JRImageStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRImageStyleConfiguration) -> Body
}

/// The default image: the picture with field-radius corners. Placeholders are a quiet
/// raised box at the spec size (else 200 × 120) with a symbol, the alt text and a note.
public struct DefaultJRImageStyle: JRImageStyle {
    public init() {}

    public func makeBody(configuration: JRImageStyleConfiguration) -> some View {
        DefaultImageBody(configuration: configuration)
    }
}

private struct DefaultImageBody: View {
    let configuration: JRImageStyleConfiguration

    var body: some View {
        let theme = configuration.theme
        let shape = RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous)
        switch configuration.content {
        case .image(let image):
            image
                .resizable()
                .aspectRatio(contentMode: configuration.fit == .cover ? .fill : .fit)
                .frame(
                    width: configuration.width, height: configuration.height
                )
                .frame(
                    maxWidth: configuration.width == nil ? .infinity : nil, alignment: .leading
                )
                .clipShape(shape)
        case .symbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(theme.color.textSecondary)
                .frame(width: configuration.width ?? 24, height: configuration.height ?? 24)
        case .placeholder(let note):
            box(note: note, button: nil)
        case .needsConsent(let host, let allow):
            box(note: "Image from \(host)", button: allow)
        case .loading(let slot):
            if let slot {
                slot
            } else {
                JRSkeletonPlaceholder(
                    shape: .block, width: configuration.width ?? 200,
                    height: configuration.height ?? 120)
            }
        case .failed(let message, let slot):
            if let slot { slot } else { box(note: message, button: nil) }
        }
    }

    private func box(note: String?, button: (@MainActor () -> Void)?) -> some View {
        let theme = configuration.theme
        return VStack(spacing: 4) {
            Image(systemName: "photo")
                .font(.system(size: 15))
                .foregroundStyle(theme.color.textMuted)
                .accessibilityHidden(true)
            if !configuration.alt.isEmpty {
                Text(configuration.alt)
                    .font(theme.type.footnote.weight(theme.type.weights.medium))
                    .foregroundStyle(theme.color.textSecondary)
            }
            if let note {
                Text(note).font(theme.type.caption).foregroundStyle(theme.color.textSecondary)
            }
            if let button {
                Button("Allow…", action: button)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .padding(theme.space.s2)
        .frame(width: configuration.width ?? 200, height: configuration.height ?? 120)
        .background(
            theme.color.surfaceRaised,
            in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous)
        )
        .standardHairline(theme, radius: theme.radius.field)
    }
}

extension EnvironmentValues {
    /// The image style. Default: `DefaultJRImageStyle`.
    @Entry public var jrImageStyle: any JRImageStyle = DefaultJRImageStyle()
}

extension View {
    /// Sets the style of every Image in this subtree.
    public func jrImageStyle(_ style: some JRImageStyle) -> some View {
        environment(\.jrImageStyle, style)
    }
}

/// `Image`: upstream shadcn props, plus `fit` and the `error` and `loading` slots.
///
/// `src` forms: `data:image/png;base64,…` (png, jpeg, gif, webp, heic; not svg); an
/// absolute path or `file:` URL inside `\.jrLocalImageRoots`; `systemName:<SF Symbol>`;
/// `https:` through `\.jrRemoteImageProvider` (none: a placeholder). Anything else draws
/// a placeholder. Nothing is fetched by the package.
@JRComponent(
    "Image",
    description:
        "Image component. Renders an img tag when src is provided, otherwise a placeholder.",
    slots: ["error", "loading"])
public struct JRImage: View {
    @JRProp var src: String?
    @JRProp var alt: String
    @JRProp var width: Double?
    @JRProp var height: Double?
    @JRProp(description: "contain (default) or cover.", oneOf: ["contain", "cover"])
    var fit: String?

    @State private var decoded: JRDecodedImage?
    @Environment(\.jrImageStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrLocalImageRoots) private var roots
    @Environment(\.jrRemoteImageProvider) private var provider
    @Environment(\.displayScale) private var displayScale

    public var body: some View {
        let source = JRImageSource(src)
        let width = JRImageSize.points(width)
        let height = JRImageSize.points(height)
        let content = imageContent(source, width: width, height: height)
        let configuration = JRImageStyleConfiguration(
            alt: alt, content: content, width: width, height: height,
            fit: fit.flatMap(JRImageFit.init(rawValue:)) ?? .contain, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .modifier(ImageAccessibility(alt: alt, content: content))
            .task(id: JRImageLoadKey(source: source, roots: roots)) {
                guard source.isLocal else { return }
                let image = await JRImageDecoder.load(
                    source, roots: roots, maxPixel: JRImageDecoder.maxPixel)
                decoded = JRDecodedImage(source: source, image: image)
            }
    }

    private func imageContent(_ source: JRImageSource, width: CGFloat?, height: CGFloat?)
        -> JRImageContent
    {
        switch source {
        case .none: return .placeholder(note: nil)
        case .symbol(let name): return .symbol(name)
        case .dataURI, .localFile:
            guard let decoded, decoded.source == source else {
                return .placeholder(note: nil)
            }
            if let image = decoded.image {
                return .image(Image(decorative: image, scale: displayScale))
            }
            return .placeholder(note: "Image not available")
        case .unsupported(let host):
            return .placeholder(note: host == nil ? nil : "Only https images load")
        case .remote(let url):
            guard let provider else {
                return .placeholder(note: url.host().map { "Image from \($0)" })
            }
            _ = provider.revision
            let pixels = CGSize(
                width: (width ?? 200) * displayScale, height: (height ?? 120) * displayScale)
            let elementID = jrContext.id
            switch provider.state(for: url, pixelSize: pixels, elementID: elementID) {
            case .notAllowed(let reason):
                return .placeholder(note: reason ?? "Images from the web are off")
            case .needsConsent(let host):
                return .needsConsent(host: host) {
                    provider.requestConsent(for: url, elementID: elementID)
                }
            case .loading:
                return .loading(jrContext.slot(JRSlots.loading).map { JRStyleContent($0) })
            case .image(let image):
                return .image(Image(decorative: image, scale: displayScale))
            case .failed(let message):
                return .failed(
                    message: message.isEmpty ? "Image did not load" : message,
                    jrContext.slot(JRSlots.error).map { JRStyleContent($0) })
            }
        }
    }
}

/// VoiceOver: a picture reads its alt text as an image; a consent box keeps its button.
private struct ImageAccessibility: ViewModifier {
    let alt: String
    let content: JRImageContent

    func body(content view: Content) -> some View {
        switch content {
        case .needsConsent:
            view.accessibilityElement(children: .contain)
                .accessibilityLabel(Text(alt.isEmpty ? "Image" : alt))
        case .loading(.some), .failed(_, .some):
            // A slot the spec filled keeps its own elements.
            view.accessibilityElement(children: .contain).accessibilityLabel(Text(alt))
        default:
            view.accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(alt.isEmpty ? "Image" : alt))
                .accessibilityAddTraits(.isImage)
        }
    }
}

/// Where a `src` points.
enum JRImageSource: Hashable, Sendable {
    case none
    case symbol(String)
    case dataURI(String)
    case localFile(URL)
    case remote(URL)
    /// A URL that never loads (http, ftp, …), with its host when it has one.
    case unsupported(host: String?)

    init(_ src: String?) {
        let text = (src ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            self = .none
        } else if text.hasPrefix("systemName:") {
            let name = String(text.dropFirst("systemName:".count))
            self = name.isEmpty ? .none : .symbol(name)
        } else if text.lowercased().hasPrefix("data:") {
            self = .dataURI(text)
        } else if text.hasPrefix("/") {
            self = .localFile(URL(fileURLWithPath: text))
        } else if let url = URL(string: text), let scheme = url.scheme?.lowercased() {
            switch scheme {
            case "https" where url.host() != nil: self = .remote(url)
            case "file": self = .localFile(url)
            default: self = .unsupported(host: url.host())
            }
        } else {
            self = .unsupported(host: nil)
        }
    }

    /// `true` for sources the package decodes itself (data URIs and local files).
    var isLocal: Bool {
        switch self {
        case .dataURI, .localFile: true
        default: false
        }
    }
}

/// The task identity of a local load.
struct JRImageLoadKey: Hashable {
    let source: JRImageSource
    let roots: [URL]
}

/// A decoded local image (or `nil` when it could not be read).
struct JRDecodedImage {
    let source: JRImageSource
    let image: CGImage?
}

/// Spec sizes: positive finite numbers only.
enum JRImageSize {
    static func points(_ value: Double?) -> CGFloat? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return CGFloat(Swift.min(value, 4096))
    }
}

/// Decodes data URIs and allowed local files off the main actor, at most `maxPixel` on
/// the long side.
enum JRImageDecoder {
    /// The long-side clamp in pixels.
    static let maxPixel = 1024
    /// The largest local file or data payload read, in bytes.
    static let maxBytes = 8 * 1024 * 1024
    /// Data URI types that decode. SVG is refused (it can reference other resources).
    static let dataTypes: Set<String> = [
        "image/png", "image/jpeg", "image/jpg", "image/gif", "image/webp", "image/heic",
    ]

    @concurrent
    static func load(_ source: JRImageSource, roots: [URL], maxPixel: Int) async -> CGImage? {
        guard let data = bytes(source, roots: roots) else { return nil }
        return decode(data, maxPixel: maxPixel)
    }

    /// The raw bytes of a data URI or an allowed local file.
    static func bytes(_ source: JRImageSource, roots: [URL]) -> Data? {
        switch source {
        case .dataURI(let text): return dataURIBytes(text)
        case .localFile(let url):
            guard let allowed = allowedFile(url, roots: roots) else { return nil }
            let size = (try? allowed.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            guard size > 0, size <= maxBytes else { return nil }
            return try? Data(contentsOf: allowed, options: .mappedIfSafe)
        default: return nil
        }
    }

    /// `data:<type>;base64,<payload>` with an allowed type.
    static func dataURIBytes(_ text: String) -> Data? {
        guard let comma = text.firstIndex(of: ",") else { return nil }
        let header = text[text.index(text.startIndex, offsetBy: 5)..<comma].lowercased()
        let parts = header.split(separator: ";").map(String.init)
        guard let type = parts.first, dataTypes.contains(type), parts.contains("base64") else {
            return nil
        }
        let payload = text[text.index(after: comma)...]
        guard payload.utf8.count <= maxBytes * 4 / 3 + 4 else { return nil }
        return Data(base64Encoded: String(payload), options: .ignoreUnknownCharacters)
    }

    /// The file URL with symbolic links resolved, when it is inside one of `roots`.
    static func allowedFile(_ url: URL, roots: [URL]) -> URL? {
        guard url.isFileURL else { return nil }
        let file = url.standardizedFileURL.resolvingSymlinksInPath()
        for root in roots where root.isFileURL {
            let base = root.standardizedFileURL.resolvingSymlinksInPath().path
            let prefix = base.hasSuffix("/") ? base : base + "/"
            if file.path.hasPrefix(prefix) { return file }
        }
        return nil
    }

    /// A thumbnail at most `maxPixel` on the long side, or `nil`.
    static func decode(_ data: Data, maxPixel: Int) -> CGImage? {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
            CGImageSourceGetCount(imageSource) > 0
        else { return nil }
        if let type = CGImageSourceGetType(imageSource) as String?, type.contains("svg") {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary)
    }
}
