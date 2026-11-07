// Owner: jr-3 (wave 2). Tabs: an underline tab bar over the children.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// One tab.
public struct JRTabItem: Hashable, Sendable, Identifiable {
    public let label: String
    public let value: String
    public var id: String { value }
}

/// The `variant` prop.
public enum JRTabsVariant: String, Sendable, CaseIterable {
    /// Text tabs over a hairline; the accent underlines the active tab (the default).
    case underline
    /// The native segmented control.
    case segmented
}

/// What a tabs style receives. `selection` changes the active tab (the component writes the
/// bound state and emits `change`); `content` is the children, drawn for every tab.
public struct JRTabsStyleConfiguration {
    public let tabs: [JRTabItem]
    public let selection: Binding<String>
    public let variant: JRTabsVariant
    public let content: JRStyleContent
    public let hasContent: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Tabs in a subtree.
public protocol JRTabsStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRTabsStyleConfiguration) -> Body
}

/// The default tabs: underline only, no pill chrome; the active tab is the primary text
/// colour with a 2 pt accent underline.
public struct DefaultJRTabsStyle: JRTabsStyle {
    public init() {}

    public func makeBody(configuration: JRTabsStyleConfiguration) -> some View {
        DefaultTabsBody(configuration: configuration)
    }
}

private struct DefaultTabsBody: View {
    let configuration: JRTabsStyleConfiguration
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: 10) {
            switch configuration.variant {
            case .segmented:
                Picker("Tabs", selection: configuration.selection) {
                    ForEach(configuration.tabs) { Text($0.label).tag($0.value) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            case .underline:
                HStack(spacing: 2) {
                    ForEach(configuration.tabs) { tab in
                        tabButton(tab, theme: theme)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(theme.color.hairline)
                        .frame(height: theme.hairlineWidth(contrast: contrast))
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("Tabs"))
            }
            if configuration.hasContent { configuration.content }
        }
    }

    private func tabButton(_ tab: JRTabItem, theme: JSONRenderTheme) -> some View {
        let selected = configuration.selection.wrappedValue == tab.value
        return Button {
            configuration.selection.wrappedValue = tab.value
        } label: {
            Text(tab.label)
                .font(
                    theme.type.body.weight(
                        selected ? theme.type.weights.medium : theme.type.weights.regular)
                )
                .foregroundStyle(selected ? theme.color.text : theme.color.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(selected ? theme.color.accent : Color.clear).frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

extension EnvironmentValues {
    /// The tabs style. Default: `DefaultJRTabsStyle`.
    @Entry public var jrTabsStyle: any JRTabsStyle = DefaultJRTabsStyle()
}

extension View {
    /// Sets the style of every Tabs in this subtree.
    public func jrTabsStyle(_ style: some JRTabsStyle) -> some View {
        environment(\.jrTabsStyle, style)
    }
}

/// `Tabs`: upstream shadcn props plus `variant`.
///
/// Upstream has no per-tab children: the children render under the bar for every tab, and
/// the spec hides them with `visible` conditions on the bound `value`. Unbound tabs keep
/// the active tab in view state (starting at `defaultValue`, else the first tab).
@JRComponent(
    "Tabs", description: "Tab navigation. Use { $bindState } on value for active tab binding.",
    slots: ["default"], events: ["change"])
public struct JRTabs: View {
    @JRProp var tabs: [JSONValue]
    @JRProp var defaultValue: String?
    @JRProp(bindable: true) var value: String?
    @JRProp(
        description: "Look: underline (default) or segmented.", oneOf: ["underline", "segmented"])
    var variant: String?

    @State private var localValue: String?
    @Environment(\.jrTabsStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `tabs` object list spelled out (the macro writes `unknown`).
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("tabs", with: StandardSchemas.labelValueList)
    }

    public var body: some View {
        let items = LabelValueItem.list(tabs).map { JRTabItem(label: $0.label, value: $0.value) }
        let first = items.first?.value ?? ""
        let current =
            jrContext.isBound("value") ? (value ?? first) : (localValue ?? defaultValue ?? first)
        let selection = Binding<String>(
            get: { current },
            set: { newValue in
                guard newValue != current else { return }
                if !jrContext.writeBound("value", .string(newValue), with: writeBinding) {
                    localValue = newValue
                }
                jrContext.emit("change", ["value": .string(newValue)])
            })
        let configuration = JRTabsStyleConfiguration(
            tabs: items, selection: selection,
            variant: variant.flatMap(JRTabsVariant.init(rawValue:)) ?? .underline,
            content: JRStyleContent(jrContext.children), hasContent: !jrContext.children.isEmpty,
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
