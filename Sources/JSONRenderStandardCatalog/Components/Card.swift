// Owner: jr-3 (wave 2). Card: a surface with a title, a description, content and slots.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// How a card draws its surface. The theme decides the look; the spec only names it.
public enum JRCardVariant: String, Sendable, CaseIterable {
    /// Surface and a hairline (the default).
    case outlined
    /// No surface, no hairline, no padding: the content groups by space only.
    case plain
    /// Surface, hairline and one soft shadow. A card inside a card draws no shadow.
    case elevated
}

/// The `maxWidth` prop.
public enum JRCardWidth: String, Sendable, CaseIterable {
    case sm, md, lg, full

    /// 384, 448, 512 pt; `nil` for `full`.
    public var points: CGFloat? {
        switch self {
        case .sm: 384
        case .md: 448
        case .lg: 512
        case .full: nil
        }
    }
}

/// What a card style receives.
public struct JRCardStyleConfiguration {
    public let title: Text?
    public let description: Text?
    public let variant: JRCardVariant
    public let maxWidth: JRCardWidth
    public let centered: Bool
    /// The `header` slot.
    public let header: JRStyleContent?
    /// The `footer` slot.
    public let footer: JRStyleContent?
    /// The children.
    public let content: JRStyleContent
    public let hasContent: Bool
    /// `true` when this card is inside another card.
    public let isNested: Bool
    public let isStreaming: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Card in a subtree (layer c). Same shape as `ButtonStyle`.
public protocol JRCardStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRCardStyleConfiguration) -> Body
}

/// The default card: 12 pt padding, 10 pt gap, a hairline where the surface starts, a
/// 15 pt semibold title over a 12 pt secondary description, footer actions at the end.
public struct DefaultJRCardStyle: JRCardStyle {
    public init() {}

    public func makeBody(configuration: JRCardStyleConfiguration) -> some View {
        DefaultCardBody(configuration: configuration)
    }
}

private struct DefaultCardBody: View {
    let configuration: JRCardStyleConfiguration
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = configuration.theme
        let variant = configuration.variant
        let shape = RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: 10) {
            if configuration.title != nil || configuration.description != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let title = configuration.title {
                        title
                            .font(theme.type.title)
                            .foregroundStyle(theme.color.text)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if let description = configuration.description {
                        description
                            .font(theme.type.footnote)
                            .foregroundStyle(theme.color.textSecondary)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let header = configuration.header { header }
            if configuration.hasContent { configuration.content }
            if let footer = configuration.footer {
                HStack(spacing: theme.space.s2) { footer }
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(variant == .plain ? 0 : theme.space.s3)
        .frame(maxWidth: configuration.maxWidth.points ?? .infinity, alignment: .leading)
        .background {
            if variant != .plain {
                shape
                    .fill(theme.color.surface)
                    .shadow(
                        color: .black.opacity(shadowOpacity(theme)),
                        radius: variant == .elevated && !configuration.isNested
                            ? theme.elevation.cardShadowRadius : 0,
                        y: variant == .elevated && !configuration.isNested
                            ? theme.elevation.cardShadowY : 0)
            }
        }
        .standardHairline(theme, radius: theme.radius.card, isVisible: variant != .plain)
        .frame(
            maxWidth: .infinity, alignment: configuration.centered ? .center : .leading)
    }

    /// 0.10 in light appearance and 0.18 in dark (the token scaled by 1.8).
    private func shadowOpacity(_ theme: JSONRenderTheme) -> Double {
        guard configuration.variant == .elevated, !configuration.isNested else { return 0 }
        let base = theme.elevation.cardShadowOpacity
        return colorScheme == .dark ? base * 1.8 : base
    }
}

extension EnvironmentValues {
    /// The card style. Default: `DefaultJRCardStyle`.
    @Entry public var jrCardStyle: any JRCardStyle = DefaultJRCardStyle()
}

extension View {
    /// Sets the style of every Card in this subtree.
    public func jrCardStyle(_ style: some JRCardStyle) -> some View {
        environment(\.jrCardStyle, style)
    }
}

/// `Card`: upstream shadcn props plus `variant`. `className` is accepted and ignored (it is
/// web-only).
@JRComponent(
    "Card",
    description:
        "Container card for content sections. Use for forms/content boxes, NOT for page headers.",
    slots: ["default", "header", "footer"])
public struct JRCard: View {
    @JRProp var title: String?
    @JRProp var description: String?
    @JRProp(oneOf: ["sm", "md", "lg", "full"]) var maxWidth: String?
    @JRProp var centered: Bool?
    @JRProp(description: "Additional CSS classes") var className: String?
    @JRProp(
        description: "Surface: outlined (default), plain (no border) or elevated (one shadow).",
        oneOf: ["outlined", "plain", "elevated"])
    var variant: String?

    @Environment(\.jrCardStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrInsideCard) private var isNested

    public var body: some View {
        let configuration = JRCardStyleConfiguration(
            title: title.map { Text($0) }, description: description.map { Text($0) },
            variant: variant.flatMap(JRCardVariant.init(rawValue:)) ?? .outlined,
            maxWidth: maxWidth.flatMap(JRCardWidth.init(rawValue:)) ?? .full,
            centered: centered ?? false,
            header: jrContext.slot(JRSlots.header).map { JRStyleContent($0) },
            footer: jrContext.slot(JRSlots.footer).map { JRStyleContent($0) },
            content: JRStyleContent(jrContext.children.environment(\.jrInsideCard, true)),
            hasContent: !jrContext.children.isEmpty, isNested: isNested,
            isStreaming: jrContext.isStreaming, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .contain)
    }
}
