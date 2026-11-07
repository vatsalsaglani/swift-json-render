// Owner: jr-3b (wave 2). Input: a one-line text field with validation.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `type` prop.
public enum JRInputType: String, Sendable, CaseIterable {
    case text, email, password, number
}

/// What an input style receives. `field` is the text field, with its focus handling,
/// events and focus ring; a style places it, it does not rebuild it.
public struct JRInputStyleConfiguration {
    public let label: String
    public let type: JRInputType
    public let field: JRStyleContent
    /// The first failing check, or `nil`.
    public let message: JRFieldMessage?
    public let theme: JSONRenderTheme
}

/// Restyles every Input in a subtree.
public protocol JRInputStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRInputStyleConfiguration) -> Body
}

/// The default input: the label above a rounded native field, the message below.
public struct DefaultJRInputStyle: JRInputStyle {
    public init() {}

    public func makeBody(configuration: JRInputStyleConfiguration) -> some View {
        StandardFieldLayout(
            label: configuration.label, control: configuration.field,
            message: configuration.message, theme: configuration.theme)
    }
}

extension EnvironmentValues {
    /// The input style. Default: `DefaultJRInputStyle`.
    @Entry public var jrInputStyle: any JRInputStyle = DefaultJRInputStyle()
}

extension View {
    /// Sets the style of every Input in this subtree.
    public func jrInputStyle(_ style: some JRInputStyle) -> some View {
        environment(\.jrInputStyle, style)
    }
}

/// `Input`: upstream shadcn props. `type: "password"` draws a secure field. `value` is a
/// secret prop: hosts must not persist or log it or the state path it binds.
@JRComponent(
    "Input",
    description:
        "Text input field. Use { $bindState } on value for two-way binding. Use checks for validation (e.g. required, email, minLength). validateOn controls timing (default: blur).",
    events: ["submit", "focus", "blur"])
public struct JRInput: View {
    @JRProp var label: String
    @JRProp var name: String
    @JRProp(oneOf: ["text", "email", "password", "number"]) var type: String?
    @JRProp var placeholder: String?
    @JRProp(bindable: true, secret: true) var value: String?
    @JRProp var checks: [JSONValue]?
    @JRProp(oneOf: ["change", "blur", "submit"]) var validateOn: String?

    @State private var localValue = ""
    @State private var validation = FormFieldValidation()
    @FocusState private var isFocused: Bool
    @Environment(\.jrInputStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `checks` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("checks", with: StandardSchemas.checks)
    }

    public var body: some View {
        let context = jrContext
        let inputType = type.flatMap(JRInputType.init(rawValue:)) ?? .text
        let spec = FormFieldSpec(
            context: context, valueProp: "value", checks: checks, validateOn: validateOn,
            defaultOn: .blur)
        let current = context.isBound("value") ? (value ?? "") : localValue
        let text = Binding<String>(
            get: { current },
            set: { newValue in
                if !context.writeBound("value", .string(newValue), with: writeBinding) {
                    localValue = newValue
                }
                validation.changed()
            })
        let field = InputField(
            type: inputType, label: label, placeholder: placeholder ?? "", text: text,
            isFocused: $isFocused, theme: theme, onSubmit: { context.emit("submit", [:]) })
        let configuration = JRInputStyleConfiguration(
            label: label, type: inputType, field: JRStyleContent(field),
            message: validation.message, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrFormField(validation, spec: spec)
            .onChange(of: isFocused) { _, focused in
                if focused {
                    context.emit("focus", [:])
                } else {
                    Task { await validation.blurred() }
                    context.emit("blur", [:])
                }
            }
    }
}

/// The text field itself: secure for `password`, plain otherwise.
private struct InputField: View {
    let type: JRInputType
    let label: String
    let placeholder: String
    let text: Binding<String>
    let isFocused: FocusState<Bool>.Binding
    let theme: JSONRenderTheme
    let onSubmit: @MainActor () -> Void

    var body: some View {
        Group {
            if type == .password {
                SecureField(label, text: text, prompt: prompt)
            } else {
                TextField(label, text: text, prompt: prompt)
                    .font(type == .number ? theme.type.body.monospacedDigit() : theme.type.body)
            }
        }
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .focused(isFocused)
        .onSubmit(onSubmit)
        .accessibilityLabel(Text(label))
    }

    private var prompt: Text? { placeholder.isEmpty ? nil : Text(placeholder) }
}
