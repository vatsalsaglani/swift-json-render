// Owner: jr-3b (wave 2). Textarea: multi-line text with validation.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a textarea style receives. `field` is the text editor with its focus handling.
public struct JRTextareaStyleConfiguration {
    public let label: String
    public let field: JRStyleContent
    public let message: JRFieldMessage?
    public let theme: JSONRenderTheme
}

/// Restyles every Textarea in a subtree.
public protocol JRTextareaStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRTextareaStyleConfiguration) -> Body
}

/// The default textarea: the label above a bordered editor, the message below.
public struct DefaultJRTextareaStyle: JRTextareaStyle {
    public init() {}

    public func makeBody(configuration: JRTextareaStyleConfiguration) -> some View {
        StandardFieldLayout(
            label: configuration.label, control: configuration.field,
            message: configuration.message, theme: configuration.theme)
    }
}

extension EnvironmentValues {
    /// The textarea style. Default: `DefaultJRTextareaStyle`.
    @Entry public var jrTextareaStyle: any JRTextareaStyle = DefaultJRTextareaStyle()
}

extension View {
    /// Sets the style of every Textarea in this subtree.
    public func jrTextareaStyle(_ style: some JRTextareaStyle) -> some View {
        environment(\.jrTextareaStyle, style)
    }
}

/// `Textarea`: upstream shadcn props. `rows` is the minimum height in lines (default 3).
@JRComponent(
    "Textarea",
    description:
        "Multi-line text input. Use { $bindState } on value for binding. Use checks for validation. validateOn controls timing (default: blur)."
)
public struct JRTextarea: View {
    @JRProp var label: String
    @JRProp var name: String
    @JRProp var placeholder: String?
    @JRProp var rows: Int?
    @JRProp(bindable: true) var value: String?
    @JRProp var checks: [JSONValue]?
    @JRProp(oneOf: ["change", "blur", "submit"]) var validateOn: String?

    @State private var localValue = ""
    @State private var validation = FormFieldValidation()
    @FocusState private var isFocused: Bool
    @Environment(\.jrTextareaStyle) private var style
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
        let lines = CGFloat(min(max(rows ?? 3, 1), 40))
        let field = TextEditor(text: text)
            .font(theme.type.body)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 4)
            .padding(.vertical, 5)
            .frame(minHeight: lines * 17 + 10, alignment: .topLeading)
            .background(
                theme.color.surfaceRaised,
                in: RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous)
            )
            .overlay(alignment: .topLeading) {
                if current.isEmpty, let placeholder, !placeholder.isEmpty {
                    Text(placeholder)
                        .font(theme.type.body)
                        .foregroundStyle(theme.color.textMuted)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .standardHairline(theme, radius: theme.radius.field)
            .focused($isFocused)
            .accessibilityLabel(Text(label))
        let configuration = JRTextareaStyleConfiguration(
            label: label, field: JRStyleContent(field), message: validation.message,
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrFormField(validation, spec: spec)
            .onChange(of: isFocused) { _, focused in
                if !focused { Task { await validation.blurred() } }
            }
    }
}
