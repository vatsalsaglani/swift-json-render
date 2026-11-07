// Owner: jr-3 (wave 2). Collapsible: one titled section that opens and closes.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a collapsible style receives.
public struct JRCollapsibleStyleConfiguration {
    public let title: String
    /// Open state. Setting it writes the bound `open` prop when there is one.
    public let isOpen: Binding<Bool>
    public let content: JRStyleContent
    public let theme: JSONRenderTheme
}

/// Restyles every Collapsible in a subtree.
public protocol JRCollapsibleStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRCollapsibleStyleConfiguration) -> Body
}

/// The default collapsible: a full-width trigger with a hairline and a chevron; the
/// children 8 pt below when open. Immediate, no animation.
public struct DefaultJRCollapsibleStyle: JRCollapsibleStyle {
    public init() {}

    public func makeBody(configuration: JRCollapsibleStyleConfiguration) -> some View {
        let theme = configuration.theme
        let isOpen = configuration.isOpen.wrappedValue
        VStack(alignment: .leading, spacing: theme.space.s2) {
            Button {
                configuration.isOpen.wrappedValue.toggle()
            } label: {
                HStack(spacing: theme.space.s2) {
                    Text(configuration.title)
                        .font(theme.type.body.weight(theme.type.weights.medium))
                        .foregroundStyle(theme.color.text)
                    Spacer(minLength: 0)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.color.textSecondary)
                        .accessibilityHidden(true)
                }
                .padding(.horizontal, theme.space.s3)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .standardHairline(theme, radius: theme.radius.control)
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(isOpen ? "Expanded" : "Collapsed"))
            if isOpen { configuration.content }
        }
    }
}

extension EnvironmentValues {
    /// The collapsible style. Default: `DefaultJRCollapsibleStyle`.
    @Entry public var jrCollapsibleStyle: any JRCollapsibleStyle = DefaultJRCollapsibleStyle()
}

extension View {
    /// Sets the style of every Collapsible in this subtree.
    public func jrCollapsibleStyle(_ style: some JRCollapsibleStyle) -> some View {
        environment(\.jrCollapsibleStyle, style)
    }
}

/// `Collapsible`: upstream shadcn props plus a bindable `open`.
@JRComponent(
    "Collapsible",
    description: "Collapsible section with trigger. Children render inside.",
    slots: ["default"])
public struct JRCollapsible: View {
    @JRProp var title: String
    @JRProp var defaultOpen: Bool?
    @JRProp(
        description: "Open state. Use { $bindState } to read or set it from state.",
        bindable: true)
    var open: Bool?

    @State private var localOpen: Bool?
    @Environment(\.jrCollapsibleStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    public var body: some View {
        let current =
            jrContext.isBound("open") ? (open ?? false) : (localOpen ?? defaultOpen ?? false)
        let binding = Binding<Bool>(
            get: { current },
            set: { newValue in
                if !jrContext.writeBound("open", .bool(newValue), with: writeBinding) {
                    localOpen = newValue
                }
            })
        let configuration = JRCollapsibleStyleConfiguration(
            title: title, isOpen: binding, content: JRStyleContent(jrContext.children),
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
