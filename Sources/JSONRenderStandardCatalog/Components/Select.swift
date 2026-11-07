// Owner: jr-3b (wave 2). Select: one value from a menu of options.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a select style receives. Setting `selection` writes the bound `value`, validates
/// and emits `change`.
public struct JRSelectStyleConfiguration {
    public let label: String
    public let options: [String]
    public let placeholder: String?
    public let selection: Binding<String?>
    public let message: JRFieldMessage?
    public let theme: JSONRenderTheme
}

/// Restyles every Select in a subtree.
public protocol JRSelectStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRSelectStyleConfiguration) -> Body
}

/// The default select: the label above a native pop-up button. With no value it shows
/// the placeholder.
public struct DefaultJRSelectStyle: JRSelectStyle {
    public init() {}

    public func makeBody(configuration: JRSelectStyleConfiguration) -> some View {
        let picker = Picker(configuration.label, selection: configuration.selection) {
            if configuration.selection.wrappedValue == nil
                || !configuration.options.contains(configuration.selection.wrappedValue ?? "")
            {
                Text(configuration.placeholder ?? "Choose…").tag(String?.none)
            }
            ForEach(configuration.options, id: \.self) { option in
                Text(option).tag(String?.some(option))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel(Text(configuration.label))
        StandardFieldLayout(
            label: configuration.label, control: JRStyleContent(picker),
            message: configuration.message, theme: configuration.theme)
    }
}

extension EnvironmentValues {
    /// The select style. Default: `DefaultJRSelectStyle`.
    @Entry public var jrSelectStyle: any JRSelectStyle = DefaultJRSelectStyle()
}

extension View {
    /// Sets the style of every Select in this subtree.
    public func jrSelectStyle(_ style: some JRSelectStyle) -> some View {
        environment(\.jrSelectStyle, style)
    }
}

/// `Select`: upstream shadcn props. `options` may come from state (`{ "$state": … }`).
@JRComponent(
    "Select",
    description:
        "Dropdown select input. Use { $bindState } on value for binding. Use checks for validation. validateOn controls timing (default: change).",
    events: ["change"])
public struct JRSelect: View {
    @JRProp var label: String
    @JRProp var name: String
    @JRProp var options: [String]
    @JRProp var placeholder: String?
    @JRProp(bindable: true) var value: String?
    @JRProp var checks: [JSONValue]?
    @JRProp(oneOf: ["change", "blur", "submit"]) var validateOn: String?

    @State private var localValue: String?
    @State private var validation = FormFieldValidation()
    @Environment(\.jrSelectStyle) private var style
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
            get: { (current?.isEmpty ?? true) ? nil : current },
            set: { newValue in
                guard let newValue, newValue != current else { return }
                if !context.writeBound("value", .string(newValue), with: writeBinding) {
                    localValue = newValue
                }
                validation.changed()
                context.emit("change", [:])
            })
        let configuration = JRSelectStyleConfiguration(
            label: label, options: StandardOptions.unique(options), placeholder: placeholder,
            selection: selection, message: validation.message, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrFormField(validation, spec: spec)
    }
}

/// Option lists with duplicates removed (a `ForEach` needs unique ids).
enum StandardOptions {
    static func unique(_ options: [String]) -> [String] {
        var seen: Set<String> = []
        return options.filter { seen.insert($0).inserted }
    }
}
