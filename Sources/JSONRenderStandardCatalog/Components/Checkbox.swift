// Owner: jr-3b (wave 2). Checkbox: one Boolean with a label.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a checkbox style receives. Setting `isOn` writes the bound `checked`, validates and
/// emits `change`.
public struct JRCheckboxStyleConfiguration {
    public let label: String
    public let isOn: Binding<Bool>
    public let message: JRFieldMessage?
    public let theme: JSONRenderTheme
}

/// Restyles every Checkbox in a subtree.
public protocol JRCheckboxStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRCheckboxStyleConfiguration) -> Body
}

/// The default checkbox: the native checkbox with its label, the message below.
public struct DefaultJRCheckboxStyle: JRCheckboxStyle {
    public init() {}

    public func makeBody(configuration: JRCheckboxStyleConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: configuration.isOn) {
                Text(configuration.label).font(configuration.theme.type.body)
            }
            .toggleStyle(.checkbox)
            if let message = configuration.message {
                JRFieldMessageView(message: message, theme: configuration.theme)
            }
        }
    }
}

extension EnvironmentValues {
    /// The checkbox style. Default: `DefaultJRCheckboxStyle`.
    @Entry public var jrCheckboxStyle: any JRCheckboxStyle = DefaultJRCheckboxStyle()
}

extension View {
    /// Sets the style of every Checkbox in this subtree.
    public func jrCheckboxStyle(_ style: some JRCheckboxStyle) -> some View {
        environment(\.jrCheckboxStyle, style)
    }
}

/// `Checkbox`: upstream shadcn props.
@JRComponent(
    "Checkbox",
    description:
        "Checkbox input. Use { $bindState } on checked for binding. Use checks for validation. validateOn controls timing (default: change).",
    events: ["change"])
public struct JRCheckbox: View {
    @JRProp var label: String
    @JRProp var name: String
    @JRProp(bindable: true) var checked: Bool?
    @JRProp var checks: [JSONValue]?
    @JRProp(oneOf: ["change", "blur", "submit"]) var validateOn: String?

    @State private var localChecked: Bool?
    @State private var validation = FormFieldValidation()
    @Environment(\.jrCheckboxStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `checks` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("checks", with: StandardSchemas.checks)
    }

    public var body: some View {
        let context = jrContext
        let spec = FormFieldSpec(
            context: context, valueProp: "checked", checks: checks, validateOn: validateOn,
            defaultOn: .change)
        let isOn = StandardBoolean.binding(
            context: context, prop: "checked", value: checked, local: $localChecked,
            writer: writeBinding, validation: validation)
        let configuration = JRCheckboxStyleConfiguration(
            label: label, isOn: isOn, message: validation.message, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrFormField(validation, spec: spec)
    }
}

/// The Boolean binding Checkbox, Switch and Toggle share: the bound prop when there is
/// one, else view state seeded from the prop.
enum StandardBoolean {
    @MainActor
    static func binding(
        context: JRRenderContext, prop: String, value: Bool?, local: Binding<Bool?>,
        writer: JRBindingWriter, validation: FormFieldValidation?
    ) -> Binding<Bool> {
        let current =
            context.isBound(prop) ? (value ?? false) : (local.wrappedValue ?? value ?? false)
        return Binding(
            get: { current },
            set: { newValue in
                guard newValue != current else { return }
                if !context.writeBound(prop, .bool(newValue), with: writer) {
                    local.wrappedValue = newValue
                }
                validation?.changed()
                context.emit("change", [:])
            })
    }
}
