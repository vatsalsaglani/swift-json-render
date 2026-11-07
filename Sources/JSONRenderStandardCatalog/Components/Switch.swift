// Owner: jr-3b (wave 2). Switch: one Boolean setting.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a switch style receives. Setting `isOn` writes the bound `checked`, validates and
/// emits `change`.
public struct JRSwitchStyleConfiguration {
    public let label: String
    public let isOn: Binding<Bool>
    public let message: JRFieldMessage?
    public let theme: JSONRenderTheme
}

/// Restyles every Switch in a subtree.
public protocol JRSwitchStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRSwitchStyleConfiguration) -> Body
}

/// The default switch: the label at the leading edge, a small native switch at the
/// trailing edge (a settings row).
public struct DefaultJRSwitchStyle: JRSwitchStyle {
    public init() {}

    public func makeBody(configuration: JRSwitchStyleConfiguration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: configuration.isOn) {
                Text(configuration.label)
                    .font(configuration.theme.type.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            if let message = configuration.message {
                JRFieldMessageView(message: message, theme: configuration.theme)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EnvironmentValues {
    /// The switch style. Default: `DefaultJRSwitchStyle`.
    @Entry public var jrSwitchStyle: any JRSwitchStyle = DefaultJRSwitchStyle()
}

extension View {
    /// Sets the style of every Switch in this subtree.
    public func jrSwitchStyle(_ style: some JRSwitchStyle) -> some View {
        environment(\.jrSwitchStyle, style)
    }
}

/// `Switch`: upstream shadcn props.
@JRComponent(
    "Switch",
    description:
        "Toggle switch. Use { $bindState } on checked for binding. Use checks for validation. validateOn controls timing (default: change).",
    events: ["change"])
public struct JRSwitch: View {
    @JRProp var label: String
    @JRProp var name: String
    @JRProp(bindable: true) var checked: Bool?
    @JRProp var checks: [JSONValue]?
    @JRProp(oneOf: ["change", "blur", "submit"]) var validateOn: String?

    @State private var localChecked: Bool?
    @State private var validation = FormFieldValidation()
    @Environment(\.jrSwitchStyle) private var style
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
        let configuration = JRSwitchStyleConfiguration(
            label: label, isOn: isOn, message: validation.message, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .jrFormField(validation, spec: spec)
    }
}
