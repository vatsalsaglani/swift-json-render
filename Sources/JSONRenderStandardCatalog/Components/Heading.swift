// Owner: jr-3 (wave 2). Heading: h1 to h4.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `level` prop.
public enum JRHeadingLevel: String, Sendable, CaseIterable {
    /// 28 pt semibold.
    case h1
    /// 20 pt semibold (`type.display`), the default.
    case h2
    /// 15 pt semibold (`type.title`).
    case h3
    /// 13 pt semibold (`type.bodyEmphasis`).
    case h4

    var accessibilityLevel: AccessibilityHeadingLevel {
        switch self {
        case .h1: .h1
        case .h2: .h2
        case .h3: .h3
        case .h4: .h4
        }
    }
}

/// What a heading style receives.
public struct JRHeadingStyleConfiguration {
    public let text: String
    public let level: JRHeadingLevel
    public let isStreaming: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Heading in a subtree. The header trait is applied outside the style, so
/// a style cannot remove it.
public protocol JRHeadingStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRHeadingStyleConfiguration) -> Body
}

/// The default heading: semibold, primary text colour, the level's size.
public struct DefaultJRHeadingStyle: JRHeadingStyle {
    public init() {}

    public func makeBody(configuration: JRHeadingStyleConfiguration) -> some View {
        let type = configuration.theme.type
        let font: Font =
            switch configuration.level {
            case .h1: .system(size: 28, weight: type.weights.semibold)
            case .h2: type.display
            case .h3: type.title
            case .h4: type.bodyEmphasis
            }
        Text(configuration.text)
            .font(font)
            .foregroundStyle(configuration.theme.color.text)
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension EnvironmentValues {
    /// The heading style. Default: `DefaultJRHeadingStyle`.
    @Entry public var jrHeadingStyle: any JRHeadingStyle = DefaultJRHeadingStyle()
}

extension View {
    /// Sets the style of every Heading in this subtree.
    public func jrHeadingStyle(_ style: some JRHeadingStyle) -> some View {
        environment(\.jrHeadingStyle, style)
    }
}

/// `Heading`: upstream shadcn props. Default level h2.
@JRComponent("Heading", description: "Heading text (h1-h4)")
public struct JRHeading: View {
    @JRProp var text: String
    @JRProp(oneOf: ["h1", "h2", "h3", "h4"]) var level: String?

    @Environment(\.jrHeadingStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let level = level.flatMap(JRHeadingLevel.init(rawValue:)) ?? .h2
        let configuration = JRHeadingStyleConfiguration(
            text: text, level: level, isStreaming: jrContext.isStreaming, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level.accessibilityLevel)
    }
}
