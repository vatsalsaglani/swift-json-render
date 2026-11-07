// Owner: jr-3b (wave 2). ToggleGroup: one or several values from a row of toggles.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// The `type` prop.
public enum JRToggleGroupType: String, Sendable, CaseIterable {
    case single, multiple
}

/// What a toggle group style receives. `selection` holds the selected values (one for
/// `single`). Setting it writes the bound `value` and emits `change`; an empty set is
/// ignored for `single`.
public struct JRToggleGroupStyleConfiguration {
    public let items: [JRTabItem]
    public let type: JRToggleGroupType
    public let selection: Binding<Set<String>>
    public let theme: JSONRenderTheme
}

/// Restyles every ToggleGroup in a subtree.
public protocol JRToggleGroupStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRToggleGroupStyleConfiguration)
        -> Body
}

/// The default toggle group: the native segmented control for `single`; a row of button
/// toggles for `multiple`.
public struct DefaultJRToggleGroupStyle: JRToggleGroupStyle {
    public init() {}

    public func makeBody(configuration: JRToggleGroupStyleConfiguration) -> some View {
        switch configuration.type {
        case .single:
            Picker(
                "Options",
                selection: Binding<String?>(
                    get: { configuration.selection.wrappedValue.first },
                    set: { configuration.selection.wrappedValue = $0.map { [$0] } ?? [] })
            ) {
                ForEach(configuration.items) { item in
                    Text(item.label).tag(String?.some(item.value))
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        case .multiple:
            HStack(spacing: configuration.theme.space.s1) {
                ForEach(configuration.items) { item in
                    Toggle(
                        item.label,
                        isOn: Binding(
                            get: { configuration.selection.wrappedValue.contains(item.value) },
                            set: { isOn in
                                var values = configuration.selection.wrappedValue
                                if isOn {
                                    values.insert(item.value)
                                } else {
                                    values.remove(item.value)
                                }
                                configuration.selection.wrappedValue = values
                            })
                    )
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                }
            }
            .fixedSize()
        }
    }
}

extension EnvironmentValues {
    /// The toggle group style. Default: `DefaultJRToggleGroupStyle`.
    @Entry public var jrToggleGroupStyle: any JRToggleGroupStyle = DefaultJRToggleGroupStyle()
}

extension View {
    /// Sets the style of every ToggleGroup in this subtree.
    public func jrToggleGroupStyle(_ style: some JRToggleGroupStyle) -> some View {
        environment(\.jrToggleGroupStyle, style)
    }
}

/// `ToggleGroup`: upstream shadcn props. As upstream, `multiple` stores the selected
/// values as one comma-separated string in item order (`"bold,italic"`). Unbound, `value`
/// (else the first item) starts selected.
@JRComponent(
    "ToggleGroup",
    description:
        "Group of toggle buttons. Type 'single' (default) or 'multiple'. Use { $bindState } on value.",
    events: ["change"])
public struct JRToggleGroup: View {
    @JRProp var items: [JSONValue]
    @JRProp(oneOf: ["single", "multiple"]) var type: String?
    @JRProp(bindable: true) var value: String?

    @State private var localValue: String?
    @Environment(\.jrToggleGroupStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    /// The definition with the `items` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("items", with: StandardSchemas.labelValueList)
    }

    public var body: some View {
        let context = jrContext
        let entries = LabelValueItem.list(items).map { JRTabItem(label: $0.label, value: $0.value) }
        let kind = type.flatMap(JRToggleGroupType.init(rawValue:)) ?? .single
        let current =
            context.isBound("value")
            ? (value ?? "") : (localValue ?? value ?? entries.first?.value ?? "")
        let selected = JRToggleGroupValue.decode(current, type: kind)
        let selection = Binding<Set<String>>(
            get: { selected },
            set: { newValue in
                if kind == .single, newValue.isEmpty { return }
                let encoded = JRToggleGroupValue.encode(newValue, order: entries.map(\.value))
                guard encoded != current else { return }
                if !context.writeBound("value", .string(encoded), with: writeBinding) {
                    localValue = encoded
                }
                context.emit("change", [:])
            })
        let configuration = JRToggleGroupStyleConfiguration(
            items: entries, type: kind, selection: selection, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .contain)
    }
}

/// The string form of a toggle group value, pure for tests.
enum JRToggleGroupValue {
    /// `single`: the value itself (empty → none). `multiple`: comma-separated, empty parts
    /// dropped.
    static func decode(_ value: String, type: JRToggleGroupType) -> Set<String> {
        switch type {
        case .single: value.isEmpty ? [] : [value]
        case .multiple: Set(value.split(separator: ",").map(String.init).filter { !$0.isEmpty })
        }
    }

    /// The selected values joined with commas, in item order.
    static func encode(_ values: Set<String>, order: [String]) -> String {
        order.filter { values.contains($0) }.joined(separator: ",")
    }
}
