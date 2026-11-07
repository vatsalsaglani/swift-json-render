// Owner: jr-3b (wave 2). Toggle: a button that stays pressed.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `variant` prop.
public enum JRToggleVariant: String, Sendable, CaseIterable {
    case `default`, outline
}

/// What a toggle style receives. Setting `isPressed` writes the bound `pressed` and emits
/// `change`.
public struct JRToggleStyleConfiguration {
    public let label: String
    public let isPressed: Binding<Bool>
    public let variant: JRToggleVariant
    public let theme: JSONRenderTheme
}

/// Restyles every Toggle in a subtree.
public protocol JRToggleStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRToggleStyleConfiguration) -> Body
}

/// The default toggle: the native bordered button toggle (the system draws the pressed
/// state). Both variants look the same; a custom style can tell them apart.
public struct DefaultJRToggleStyle: JRToggleStyle {
    public init() {}

    public func makeBody(configuration: JRToggleStyleConfiguration) -> some View {
        Toggle(configuration.label, isOn: configuration.isPressed)
            .toggleStyle(.button)
            .buttonStyle(.bordered)
            .font(configuration.theme.type.body)
            .accessibilityValue(Text(configuration.isPressed.wrappedValue ? "On" : "Off"))
    }
}

extension EnvironmentValues {
    /// The toggle style. Default: `DefaultJRToggleStyle`.
    @Entry public var jrToggleStyle: any JRToggleStyle = DefaultJRToggleStyle()
}

extension View {
    /// Sets the style of every Toggle in this subtree.
    public func jrToggleStyle(_ style: some JRToggleStyle) -> some View {
        environment(\.jrToggleStyle, style)
    }
}

/// `Toggle`: upstream shadcn props.
@JRComponent(
    "Toggle", description: "Toggle button. Use { $bindState } on pressed for state binding.",
    events: ["change"])
public struct JRToggle: View {
    @JRProp var label: String
    @JRProp(bindable: true) var pressed: Bool?
    @JRProp(oneOf: ["default", "outline"]) var variant: String?

    @State private var localPressed: Bool?
    @Environment(\.jrToggleStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    public var body: some View {
        let isPressed = StandardBoolean.binding(
            context: jrContext, prop: "pressed", value: pressed, local: $localPressed,
            writer: writeBinding, validation: nil)
        let configuration = JRToggleStyleConfiguration(
            label: label, isPressed: isPressed,
            variant: variant.flatMap(JRToggleVariant.init(rawValue:)) ?? .default, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
