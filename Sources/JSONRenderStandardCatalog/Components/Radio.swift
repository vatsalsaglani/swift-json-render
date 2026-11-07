// Owner: jr-3b (wave 2). Radio: one value from a short list, all options visible.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a radio style receives. Setting `selection` writes the bound `value`, validates
/// and emits `change`.
public struct JRRadioStyleConfiguration {
    public let label: String
    public let options: [String]
    public let selection: Binding<String?>
    public let message: JRFieldMessage?
    public let theme: JSONRenderTheme
}

/// Restyles every Radio in a subtree.
public protocol JRRadioStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRRadioStyleConfiguration) -> Body
}

/// The default radio: the label above a native vertical radio group.
public struct DefaultJRRadioStyle: JRRadioStyle {
    public init() {}

    public func makeBody(configuration: JRRadioStyleConfiguration) -> some View {
        let group = Picker(configuration.label, selection: configuration.selection) {
            ForEach(configuration.options, id: \.self) { option in
                Text(option).font(configuration.theme.type.body).tag(String?.some(option))
            }
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()
        .accessibilityLabel(Text(configuration.label))
        StandardFieldLayout(
            label: configuration.label, control: JRStyleContent(group),
            message: configuration.message, theme: configuration.theme)
    }
}

extension EnvironmentValues {
    /// The radio style. Default: `DefaultJRRadioStyle`.
    @Entry public var jrRadioStyle: any JRRadioStyle = DefaultJRRadioStyle()
}

extension View {
    /// Sets the style of every Radio in this subtree.
    public func jrRadioStyle(_ style: some JRRadioStyle) -> some View {
        environment(\.jrRadioStyle, style)
    }
}

/// `Radio`: upstream shadcn props.
@JRComponent(
    "Radio",
    description:
        "Radio button group. Use { $bindState } on value for binding. Use checks for validation. validateOn controls timing (default: change).",
    events: ["change"])
public struct JRRadio: View {
    @JRProp var label: String
    @JRProp var name: String
    @JRProp var options: [String]
    @JRProp(bindable: true) var value: String?
    @JRProp var checks: [JSONValue]?
    @JRProp(oneOf: ["change", "blur", "submit"]) var validateOn: String?

    @State private var localValue: String?
    @State private var validation = FormFieldValidation()
    @Environment(\.jrRadioStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `checks` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("checks", with: StandardSchemas.checks)
    }

    public var body: some View {
        let context = jrContext
        let spec = FormFieldSpec(
            context: context, valueProp: "value", checks: checks, validateOn: validateOn,
            defaultOn: .change)
        let current = context.isBound("value") ? value : (localValue ?? value)
        let selection = Binding<String?>(
            get: { current },
            set: { newValue in
                guard let newValue, newValue != current else { return }
                if !context.writeBound("value", .string(newValue), with: writeBinding) {
                    localValue = newValue
                }
                validation.changed()
                context.emit("change", [:])
            })
        let configuration = JRRadioStyleConfiguration(
            label: label, options: StandardOptions.unique(options), selection: selection,
            message: validation.message, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrFormField(validation, spec: spec)
    }
}
