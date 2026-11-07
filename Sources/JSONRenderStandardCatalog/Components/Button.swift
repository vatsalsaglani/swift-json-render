// Owner: jr-3b (wave 2). Button: one press action.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `variant` prop. `destructive` is an alias of `danger`.
public enum JRButtonVariant: String, Sendable, CaseIterable {
    case primary, secondary, danger, destructive, plain

    /// `destructive` reads as `danger`.
    var canonical: JRButtonVariant { self == .destructive ? .danger : self }
}

/// What a button style receives. `press` emits the element's `press` event.
public struct JRButtonStyleConfiguration {
    public let label: String
    public let variant: JRButtonVariant
    /// An SF Symbol name, or `nil`.
    public let icon: String?
    public let isDisabled: Bool
    /// `true` for the one primary button that owns the default keyboard action (Return).
    public let isDefaultAction: Bool
    public let press: @MainActor () -> Void
    public let theme: JSONRenderTheme
}

/// Restyles every Button in a subtree.
public protocol JRButtonStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRButtonStyleConfiguration) -> Body
}

/// The default button: a native bordered button. `primary` is prominent (the accent) and
/// takes Return when it is the first primary in the view; `danger` has the destructive
/// role and its label in the critical colour; `plain` is borderless.
public struct DefaultJRButtonStyle: JRButtonStyle {
    public init() {}

    public func makeBody(configuration: JRButtonStyleConfiguration) -> some View {
        let variant = configuration.variant.canonical
        let button = Button(
            role: variant == .danger ? .destructive : nil, action: configuration.press
        ) {
            // A bordered macOS button ignores `tint`: the danger word carries the colour.
            if variant == .danger, !configuration.isDisabled {
                ButtonLabel(configuration: configuration)
                    .foregroundStyle(configuration.theme.color.critical)
            } else {
                ButtonLabel(configuration: configuration)
            }
        }
        .disabled(configuration.isDisabled)
        .keyboardShortcut(configuration.isDefaultAction ? .defaultAction : nil)
        switch variant {
        case .primary:
            button.buttonStyle(.borderedProminent)
        case .danger, .destructive:
            button.buttonStyle(.bordered)
        case .plain:
            button.buttonStyle(.borderless)
        case .secondary:
            button.buttonStyle(.bordered)
        }
    }
}

/// The label text, with the icon when the spec names one.
private struct ButtonLabel: View {
    let configuration: JRButtonStyleConfiguration

    var body: some View {
        if let icon = configuration.icon {
            Label(configuration.label, systemImage: icon)
        } else {
            Text(configuration.label)
        }
    }
}

extension EnvironmentValues {
    /// The button style. Default: `DefaultJRButtonStyle`.
    @Entry public var jrButtonStyle: any JRButtonStyle = DefaultJRButtonStyle()
}

extension View {
    /// Sets the style of every Button in this subtree.
    public func jrButtonStyle(_ style: some JRButtonStyle) -> some View {
        environment(\.jrButtonStyle, style)
    }
}

/// `Button`: upstream shadcn props, plus `destructive` and `plain` variants, `size` and
/// `icon`.
@JRComponent(
    "Button", description: "Clickable button. Bind on.press for handler.", events: ["press"])
public struct JRButton: View {
    @JRProp var label: String
    @JRProp(oneOf: ["primary", "secondary", "danger", "destructive", "plain"])
    var variant: String?
    @JRProp var disabled: Bool?
    @JRProp(description: "Control size (default md).", oneOf: ["sm", "md", "lg"])
    var size: String?
    @JRProp(description: "SF Symbol name shown before the label.") var icon: String?

    @Environment(\.jrButtonStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrDefaultActionElementID) private var defaultActionID

    public var body: some View {
        let context = jrContext
        let configuration = JRButtonStyleConfiguration(
            label: label,
            variant: variant.flatMap(JRButtonVariant.init(rawValue:)) ?? .secondary,
            icon: icon.flatMap { $0.isEmpty ? nil : $0 },
            isDisabled: disabled ?? false,
            // Repeated rows share the element id: only a button outside a repeat takes Return.
            isDefaultAction: defaultActionID == context.id && context.scope == nil,
            press: { context.emit("press", [:]) },
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrControlSize(size)
            .accessibilityLabel(Text(label))
    }
}
