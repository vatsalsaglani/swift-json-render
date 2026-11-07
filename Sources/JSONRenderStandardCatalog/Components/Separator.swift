// Owner: jr-3 (wave 2). Separator: one hairline.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a separator style receives.
public struct JRSeparatorStyleConfiguration {
    /// `.horizontal` draws a line across; `.vertical` a line down.
    public let orientation: Axis
    /// 1 pt; 2 pt under Increase Contrast or with the high-contrast hairline.
    public let thickness: CGFloat
    public let theme: JSONRenderTheme
}

/// Restyles every Separator in a subtree.
public protocol JRSeparatorStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRSeparatorStyleConfiguration) -> Body
}

/// The default separator: the hairline colour at hairline width. Hidden from VoiceOver.
public struct DefaultJRSeparatorStyle: JRSeparatorStyle {
    public init() {}

    public func makeBody(configuration: JRSeparatorStyleConfiguration) -> some View {
        let line = Rectangle().fill(configuration.theme.color.hairline)
        if configuration.orientation == .horizontal {
            line.frame(height: configuration.thickness).frame(maxWidth: .infinity)
        } else {
            line.frame(width: configuration.thickness).frame(minHeight: 16, maxHeight: .infinity)
        }
    }
}

extension EnvironmentValues {
    /// The separator style. Default: `DefaultJRSeparatorStyle`.
    @Entry public var jrSeparatorStyle: any JRSeparatorStyle = DefaultJRSeparatorStyle()
}

extension View {
    /// Sets the style of every Separator in this subtree.
    public func jrSeparatorStyle(_ style: some JRSeparatorStyle) -> some View {
        environment(\.jrSeparatorStyle, style)
    }
}

/// `Separator`: upstream shadcn props.
@JRComponent("Separator", description: "Visual separator line")
public struct JRSeparator: View {
    @JRProp(oneOf: ["horizontal", "vertical"]) var orientation: String?

    @Environment(\.jrSeparatorStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    public var body: some View {
        let configuration = JRSeparatorStyleConfiguration(
            orientation: orientation == "vertical" ? .vertical : .horizontal,
            thickness: theme.hairlineWidth(contrast: contrast), theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityHidden(true)
    }
}
