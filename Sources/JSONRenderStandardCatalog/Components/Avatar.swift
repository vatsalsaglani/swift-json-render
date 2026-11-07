// Owner: jr-3b (wave 2). Avatar: a round picture, or the initials of a name.
public import CoreGraphics
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `size` prop: sm 24 pt, md 32 pt (default), lg 44 pt.
public enum JRAvatarSize: String, Sendable, CaseIterable {
    case sm, md, lg

    public var diameter: CGFloat {
        switch self {
        case .sm: 24
        case .md: 32
        case .lg: 44
        }
    }
}

/// What an avatar style receives. With no `image` and no `symbol`, the initials show.
public struct JRAvatarStyleConfiguration {
    public let name: String
    public let initials: String
    public let image: Image?
    /// An SF Symbol name (`src: "systemName:<name>"`).
    public let symbol: String?
    public let size: JRAvatarSize
    public let theme: JSONRenderTheme
}

/// Restyles every Avatar in a subtree.
public protocol JRAvatarStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRAvatarStyleConfiguration) -> Body
}

/// The default avatar: a circle with a hairline; the picture fills it, or the initials in
/// semibold secondary text on the raised surface.
public struct DefaultJRAvatarStyle: JRAvatarStyle {
    public init() {}

    public func makeBody(configuration: JRAvatarStyleConfiguration) -> some View {
        let theme = configuration.theme
        let diameter = configuration.size.diameter
        ZStack {
            Circle().fill(theme.color.surfaceRaised)
            if let image = configuration.image {
                image.resizable().scaledToFill()
            } else if let symbol = configuration.symbol {
                Image(systemName: symbol)
                    .font(.system(size: (diameter * 0.5).rounded()))
                    .foregroundStyle(theme.color.textSecondary)
            } else {
                Text(configuration.initials)
                    .font(.system(size: (diameter * 0.4).rounded(), weight: .semibold))
                    .foregroundStyle(theme.color.textSecondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay { Circle().strokeBorder(theme.color.hairline, lineWidth: 1) }
    }
}

extension EnvironmentValues {
    /// The avatar style. Default: `DefaultJRAvatarStyle`.
    @Entry public var jrAvatarStyle: any JRAvatarStyle = DefaultJRAvatarStyle()
}

extension View {
    /// Sets the style of every Avatar in this subtree.
    public func jrAvatarStyle(_ style: some JRAvatarStyle) -> some View {
        environment(\.jrAvatarStyle, style)
    }
}

/// `Avatar`: upstream shadcn props. `src` takes the same forms as Image; an https picture
/// shows only when the host's provider has it, else the initials (an avatar never asks
/// for consent).
@JRComponent("Avatar", description: "User avatar with fallback initials")
public struct JRAvatar: View {
    @JRProp var src: String?
    @JRProp var name: String
    @JRProp(oneOf: ["sm", "md", "lg"]) var size: String?

    @State private var decoded: JRDecodedImage?
    @Environment(\.jrAvatarStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrLocalImageRoots) private var roots
    @Environment(\.jrRemoteImageProvider) private var provider
    @Environment(\.displayScale) private var displayScale

    public var body: some View {
        let source = JRImageSource(src)
        let size = size.flatMap(JRAvatarSize.init(rawValue:)) ?? .md
        let configuration = JRAvatarStyleConfiguration(
            name: name, initials: JRAvatarInitials.make(name),
            image: picture(source, diameter: size.diameter),
            symbol: { if case .symbol(let name) = source { name } else { nil } }(),
            size: size, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(name.isEmpty ? "Avatar" : name))
            .accessibilityAddTraits(.isImage)
            .task(id: JRImageLoadKey(source: source, roots: roots)) {
                guard source.isLocal else { return }
                let image = await JRImageDecoder.load(source, roots: roots, maxPixel: 256)
                decoded = JRDecodedImage(source: source, image: image)
            }
    }

    private func picture(_ source: JRImageSource, diameter: CGFloat) -> Image? {
        switch source {
        case .dataURI, .localFile:
            guard let decoded, decoded.source == source, let image = decoded.image else {
                return nil
            }
            return Image(decorative: image, scale: displayScale)
        case .remote(let url):
            guard let provider else { return nil }
            _ = provider.revision
            let pixels = CGSize(width: diameter * displayScale, height: diameter * displayScale)
            if case .image(let image) = provider.state(
                for: url, pixelSize: pixels, elementID: jrContext.id)
            {
                return Image(decorative: image, scale: displayScale)
            }
            return nil
        case .none, .unsupported, .symbol:
            return nil
        }
    }
}

/// Upstream initials: the first letter of each space-separated word, the first two,
/// upper-cased; "?" for an empty name.
enum JRAvatarInitials {
    static func make(_ name: String) -> String {
        let words = name.split(separator: " ", omittingEmptySubsequences: true)
        let letters = words.compactMap(\.first).prefix(2).map { String($0) }.joined()
        return letters.isEmpty ? "?" : letters.uppercased()
    }
}
