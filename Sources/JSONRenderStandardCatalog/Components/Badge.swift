// Owner: jr-3 (wave 2). Badge: a short label, optionally with a status.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `variant` prop. `destructive` is the upstream name for `critical`.
public enum JRBadgeVariant: String, Sendable, CaseIterable {
    case `default`, secondary, destructive, outline, good, warning, critical

    /// The status the variant carries, or `nil` for a neutral badge.
    var status: StandardStatus? {
        switch self {
        case .destructive, .critical: .critical
        case .good: .good
        case .warning: .warning
        case .default, .secondary, .outline: nil
        }
    }
}

/// What a badge style receives.
public struct JRBadgeStyleConfiguration {
    public let text: String
    public let variant: JRBadgeVariant
    /// The SF Symbol of a status variant (`nil` for neutral variants).
    public let symbol: String?
    /// The status hue (`nil` for neutral variants). Use it with the symbol, never alone.
    public let statusColor: Color?
    public let theme: JSONRenderTheme
}

/// Restyles every Badge in a subtree.
public protocol JRBadgeStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRBadgeStyleConfiguration) -> Body
}

/// The default badge: an 11 pt semibold capsule. Status variants add a symbol and a
/// border in the status hue; the word stays in a text colour for contrast.
public struct DefaultJRBadgeStyle: JRBadgeStyle {
    public init() {}

    public func makeBody(configuration: JRBadgeStyleConfiguration) -> some View {
        DefaultBadgeBody(configuration: configuration)
    }
}

private struct DefaultBadgeBody: View {
    let configuration: JRBadgeStyleConfiguration
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let theme = configuration.theme
        let capsule = Capsule(style: .circular)
        HStack(spacing: 4) {
            if let symbol = configuration.symbol {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(configuration.statusColor ?? theme.color.textSecondary)
            }
            Text(configuration.text)
                .font(theme.type.caption.weight(theme.type.weights.semibold))
                .foregroundStyle(
                    configuration.variant == .default ? theme.color.text : theme.color.textSecondary
                )
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background {
            if configuration.variant == .default || configuration.variant == .secondary {
                capsule.fill(theme.color.surfaceRaised)
            }
        }
        .overlay {
            if configuration.variant != .secondary {
                capsule.strokeBorder(
                    configuration.statusColor ?? theme.color.hairline,
                    lineWidth: theme.hairlineWidth(contrast: contrast))
            }
        }
        .fixedSize()
    }
}

extension EnvironmentValues {
    /// The badge style. Default: `DefaultJRBadgeStyle`.
    @Entry public var jrBadgeStyle: any JRBadgeStyle = DefaultJRBadgeStyle()
}

extension View {
    /// Sets the style of every Badge in this subtree.
    public func jrBadgeStyle(_ style: some JRBadgeStyle) -> some View {
        environment(\.jrBadgeStyle, style)
    }
}

/// `Badge`: upstream shadcn props; `variant` also accepts `good`, `warning`, `critical`.
@JRComponent("Badge", description: "Status badge")
public struct JRBadge: View {
    @JRProp var text: String
    @JRProp(
        oneOf: ["default", "secondary", "destructive", "outline", "good", "warning", "critical"])
    var variant: String?

    @Environment(\.jrBadgeStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let variant = variant.flatMap(JRBadgeVariant.init(rawValue:)) ?? .default
        let status = variant.status
        let configuration = JRBadgeStyleConfiguration(
            text: text, variant: variant, symbol: status?.symbol,
            statusColor: status?.color(theme), theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(status.map { "\($0.word): \(text)" } ?? text))
    }
}
