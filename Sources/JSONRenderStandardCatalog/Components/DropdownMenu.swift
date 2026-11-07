// Owner: jr-3 (wave 2). DropdownMenu: a menu button that selects one value.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a dropdown menu style receives. Setting `selection` writes the bound `value` and
/// emits `select`.
public struct JRDropdownMenuStyleConfiguration {
    public let label: String
    public let items: [JRTabItem]
    public let selection: Binding<String?>
    public let theme: JSONRenderTheme
}

/// Restyles every DropdownMenu in a subtree.
public protocol JRDropdownMenuStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRDropdownMenuStyleConfiguration)
        -> Body
}

/// The default dropdown menu: a native menu button showing the label; the selected item
/// has a checkmark.
public struct DefaultJRDropdownMenuStyle: JRDropdownMenuStyle {
    public init() {}

    public func makeBody(configuration: JRDropdownMenuStyleConfiguration) -> some View {
        Menu {
            ForEach(configuration.items) { item in
                Button {
                    configuration.selection.wrappedValue = item.value
                } label: {
                    if configuration.selection.wrappedValue == item.value {
                        Label(item.label, systemImage: "checkmark")
                    } else {
                        Text(item.label)
                    }
                }
            }
        } label: {
            Text(configuration.label)
        }
        .menuStyle(.button)
        .fixedSize()
        .accessibilityValue(
            Text(
                configuration.items.first { $0.value == configuration.selection.wrappedValue }?
                    .label ?? ""))
    }
}

extension EnvironmentValues {
    /// The dropdown menu style. Default: `DefaultJRDropdownMenuStyle`.
    @Entry public var jrDropdownMenuStyle: any JRDropdownMenuStyle = DefaultJRDropdownMenuStyle()
}

extension View {
    /// Sets the style of every DropdownMenu in this subtree.
    public func jrDropdownMenuStyle(_ style: some JRDropdownMenuStyle) -> some View {
        environment(\.jrDropdownMenuStyle, style)
    }
}

/// `DropdownMenu`: upstream shadcn props. An unbound `value` is kept in view state.
@JRComponent(
    "DropdownMenu",
    description:
        "Dropdown menu with trigger button and selectable items. Use { $bindState } on value for selected item binding.",
    events: ["select"])
public struct JRDropdownMenu: View {
    @JRProp var label: String
    @JRProp var items: [JSONValue]
    @JRProp(bindable: true) var value: String?

    @State private var localValue: String?
    @Environment(\.jrDropdownMenuStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `items` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("items", with: StandardSchemas.labelValueList)
    }

    public var body: some View {
        let entries = LabelValueItem.list(items).map { JRTabItem(label: $0.label, value: $0.value) }
        let current = jrContext.isBound("value") ? value : (localValue ?? value)
        let selection = Binding<String?>(
            get: { current },
            set: { newValue in
                guard let newValue else { return }
                if !jrContext.writeBound("value", .string(newValue), with: writeBinding) {
                    localValue = newValue
                }
                jrContext.emit("select", ["value": .string(newValue)])
            })
        let configuration = JRDropdownMenuStyleConfiguration(
            label: label, items: entries, selection: selection, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
