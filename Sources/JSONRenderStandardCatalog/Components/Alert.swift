// Owner: jr-3 (wave 2). Alert: a callout with a status edge, a symbol and words.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `type` prop.
public enum JRAlertType: String, Sendable, CaseIterable {
    case info, success, warning, error

    var status: StandardStatus {
        switch self {
        case .info: .info
        case .success: .good
        case .warning: .warning
        case .error: .critical
        }
    }
}

/// What an alert style receives.
public struct JRAlertStyleConfiguration {
    public let title: String
    public let message: String?
    public let type: JRAlertType
    /// The SF Symbol for the type.
    public let symbol: String
    /// The status hue for the edge and the symbol.
    public let statusColor: Color
    public let theme: JSONRenderTheme
}

/// Restyles every Alert in a subtree. VoiceOver reads the type word first in every style.
public protocol JRAlertStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRAlertStyleConfiguration) -> Body
}

/// The default alert: a 3 pt edge and a symbol in the status hue, a 13 pt semibold title
/// and a 12 pt secondary message, inside a hairline box. Never colour alone.
public struct DefaultJRAlertStyle: JRAlertStyle {
    public init() {}

    public func makeBody(configuration: JRAlertStyleConfiguration) -> some View {
        let theme = configuration.theme
        let shape = RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous)
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: configuration.symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(configuration.statusColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.title)
                    .font(theme.type.bodyEmphasis)
                    .foregroundStyle(theme.color.text)
                if let message = configuration.message {
                    Text(message)
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.vertical, theme.space.s2)
        .padding(.leading, theme.space.s3)
        .padding(.trailing, theme.space.s3)
        .background(shape.fill(theme.color.surface))
        .overlay(alignment: .leading) {
            Rectangle().fill(configuration.statusColor).frame(width: 3)
        }
        .clipShape(shape)
        .standardHairline(theme, radius: theme.radius.field)
    }
}

extension EnvironmentValues {
    /// The alert style. Default: `DefaultJRAlertStyle`.
    @Entry public var jrAlertStyle: any JRAlertStyle = DefaultJRAlertStyle()
}

extension View {
    /// Sets the style of every Alert in this subtree.
    public func jrAlertStyle(_ style: some JRAlertStyle) -> some View {
        environment(\.jrAlertStyle, style)
    }
}

/// `Alert`: upstream shadcn props. Default type `info`.
@JRComponent("Alert", description: "Alert banner")
public struct JRAlert: View {
    @JRProp var title: String
    @JRProp var message: String?
    @JRProp(oneOf: ["info", "success", "warning", "error"]) var type: String?

    @Environment(\.jrAlertStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let kind = type.flatMap(JRAlertType.init(rawValue:)) ?? .info
        let configuration = JRAlertStyleConfiguration(
            title: title, message: message, type: kind, symbol: kind.status.symbol,
            statusColor: kind.status.color(theme), theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(kind.status.word): \(title)"))
            .accessibilityValue(Text(message ?? ""))
    }
}
