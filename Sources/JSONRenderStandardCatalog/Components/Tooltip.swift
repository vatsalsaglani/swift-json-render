// Owner: jr-3 (wave 2). Tooltip: text with a hover help tag.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a tooltip style receives.
public struct JRTooltipStyleConfiguration {
    /// The visible text.
    public let text: String
    /// The help text shown on hover (and read by VoiceOver as a hint).
    public let content: String
    public let theme: JSONRenderTheme
}

/// Restyles every Tooltip in a subtree. The help tag and the hint are applied outside the
/// style.
public protocol JRTooltipStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRTooltipStyleConfiguration) -> Body
}

/// The default tooltip: body text with a dotted underline that marks it as having help.
public struct DefaultJRTooltipStyle: JRTooltipStyle {
    public init() {}

    public func makeBody(configuration: JRTooltipStyleConfiguration) -> some View {
        Text(configuration.text)
            .font(configuration.theme.type.body)
            .foregroundStyle(configuration.theme.color.text)
            .underline(pattern: .dot, color: configuration.theme.color.textSecondary)
    }
}

extension EnvironmentValues {
    /// The tooltip style. Default: `DefaultJRTooltipStyle`.
    @Entry public var jrTooltipStyle: any JRTooltipStyle = DefaultJRTooltipStyle()
}

extension View {
    /// Sets the style of every Tooltip in this subtree.
    public func jrTooltipStyle(_ style: some JRTooltipStyle) -> some View {
        environment(\.jrTooltipStyle, style)
    }
}

/// `Tooltip`: upstream shadcn props (`content` is the tip, `text` the visible text).
@JRComponent("Tooltip", description: "Hover tooltip. Shows content on hover over text.")
public struct JRTooltip: View {
    @JRProp var content: String
    @JRProp var text: String

    @Environment(\.jrTooltipStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let configuration = JRTooltipStyleConfiguration(text: text, content: content, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .help(Text(content))
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text(content))
    }
}
