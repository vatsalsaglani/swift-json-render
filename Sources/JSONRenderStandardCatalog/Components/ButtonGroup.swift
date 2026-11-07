// Owner: jr-3b (wave 2). ButtonGroup: joined buttons, one selected.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a button group style receives. Setting `selection` writes the bound `selected`
/// and emits `change`.
public struct JRButtonGroupStyleConfiguration {
    public let buttons: [JRTabItem]
    public let selection: Binding<String?>
    public let theme: JSONRenderTheme
}

/// Restyles every ButtonGroup in a subtree.
public protocol JRButtonGroupStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRButtonGroupStyleConfiguration)
        -> Body
}

/// The default button group: the native segmented control (joined buttons; the system
/// marks the selected one).
public struct DefaultJRButtonGroupStyle: JRButtonGroupStyle {
    public init() {}

    public func makeBody(configuration: JRButtonGroupStyleConfiguration) -> some View {
        Picker("Options", selection: configuration.selection) {
            ForEach(configuration.buttons) { button in
                Text(button.label).tag(String?.some(button.value))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

extension EnvironmentValues {
    /// The button group style. Default: `DefaultJRButtonGroupStyle`.
    @Entry public var jrButtonGroupStyle: any JRButtonGroupStyle = DefaultJRButtonGroupStyle()
}

extension View {
    /// Sets the style of every ButtonGroup in this subtree.
    public func jrButtonGroupStyle(_ style: some JRButtonGroupStyle) -> some View {
        environment(\.jrButtonGroupStyle, style)
    }
}

/// `ButtonGroup`: upstream shadcn props. Unbound, `selected` (else the first button) starts selected.
@JRComponent(
    "ButtonGroup",
    description: "Segmented button group. Use { $bindState } on selected for selected value.",
    events: ["change"])
public struct JRButtonGroup: View {
    @JRProp var buttons: [JSONValue]
    @JRProp(bindable: true) var selected: String?

    @State private var localValue: String?
    @Environment(\.jrButtonGroupStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `buttons` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("buttons", with: StandardSchemas.labelValueList)
    }

    public var body: some View {
        let context = jrContext
        let entries = LabelValueItem.list(buttons).map {
            JRTabItem(label: $0.label, value: $0.value)
        }
        let current =
            context.isBound("selected")
            ? selected : (localValue ?? selected ?? entries.first?.value)
        let selection = Binding<String?>(
            get: { current },
            set: { newValue in
                guard let newValue, newValue != current else { return }
                if !context.writeBound("selected", .string(newValue), with: writeBinding) {
                    localValue = newValue
                }
                context.emit("change", [:])
            })
        let configuration = JRButtonGroupStyleConfiguration(
            buttons: entries, selection: selection, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .contain)
    }
}
