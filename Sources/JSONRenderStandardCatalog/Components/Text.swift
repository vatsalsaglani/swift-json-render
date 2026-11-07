// Owner: jr-3 (wave 2). Text: one paragraph.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `variant` prop of Text.
public enum JRTextVariant: String, Sendable, CaseIterable {
    /// 13 pt, primary text.
    case body
    /// 11 pt, secondary text.
    case caption
    /// 12 pt, secondary text.
    case muted
    /// 15 pt regular, secondary text: an introduction.
    case lead
    /// 12 pt monospaced on the raised surface.
    case code
}

/// What a text style receives.
public struct JRTextStyleConfiguration {
    public let text: String
    public let variant: JRTextVariant
    public let isStreaming: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Text in a subtree.
public protocol JRTextStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRTextStyleConfiguration) -> Body
}

/// The default text: the theme's type ramp, selectable, wrapping.
public struct DefaultJRTextStyle: JRTextStyle {
    public init() {}

    public func makeBody(configuration: JRTextStyleConfiguration) -> some View {
        let theme = configuration.theme
        let text = Text(configuration.text)
        switch configuration.variant {
        case .body:
            text.font(theme.type.body).foregroundStyle(theme.color.text)
                .fixedSize(horizontal: false, vertical: true)
        case .caption:
            text.font(theme.type.caption).foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .muted:
            text.font(theme.type.footnote).foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .lead:
            text.font(theme.type.title.weight(theme.type.weights.regular))
                .foregroundStyle(theme.color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        case .code:
            text.font(theme.type.mono).foregroundStyle(theme.color.text)
                .padding(.horizontal, theme.space.s1)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(theme.color.surfaceRaised)
                )
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension EnvironmentValues {
    /// The text style. Default: `DefaultJRTextStyle`.
    @Entry public var jrTextStyle: any JRTextStyle = DefaultJRTextStyle()
}

extension View {
    /// Sets the style of every Text in this subtree.
    public func jrTextStyle(_ style: some JRTextStyle) -> some View {
        environment(\.jrTextStyle, style)
    }
}

/// `Text`: upstream shadcn props.
@JRComponent("Text", description: "Paragraph text")
public struct JRText: View {
    @JRProp var text: String
    @JRProp(oneOf: ["body", "caption", "muted", "lead", "code"]) var variant: String?

    @Environment(\.jrTextStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let configuration = JRTextStyleConfiguration(
            text: text, variant: variant.flatMap(JRTextVariant.init(rawValue:)) ?? .body,
            isStreaming: jrContext.isStreaming, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .textSelection(.enabled)
    }
}
