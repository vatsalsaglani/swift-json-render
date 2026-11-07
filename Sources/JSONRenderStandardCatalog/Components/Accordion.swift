// Owner: jr-3 (wave 2). Accordion: collapsible text sections.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// One accordion section.
public struct JRAccordionItem: Hashable, Sendable, Identifiable {
    public let title: String
    public let content: String
    /// The position in `items`.
    public let id: Int
}

/// The `type` prop.
public enum JRAccordionMode: String, Sendable, CaseIterable {
    /// One section open at a time (the default).
    case single
    /// Any number of sections open.
    case multiple
}

/// What an accordion style receives. `expanded` holds the open section ids; the component
/// enforces `single`.
public struct JRAccordionStyleConfiguration {
    public let items: [JRAccordionItem]
    public let mode: JRAccordionMode
    public let expanded: Binding<Set<Int>>
    public let theme: JSONRenderTheme
}

/// Restyles every Accordion in a subtree.
public protocol JRAccordionStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRAccordionStyleConfiguration) -> Body
}

/// The default accordion: rows separated by hairlines, a semibold title with a chevron,
/// 12 pt secondary content. Opening is immediate (no animation).
public struct DefaultJRAccordionStyle: JRAccordionStyle {
    public init() {}

    public func makeBody(configuration: JRAccordionStyleConfiguration) -> some View {
        DefaultAccordionBody(configuration: configuration)
    }
}

private struct DefaultAccordionBody: View {
    let configuration: JRAccordionStyleConfiguration
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: 0) {
            ForEach(configuration.items) { item in
                let isOpen = configuration.expanded.wrappedValue.contains(item.id)
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        var open = configuration.expanded.wrappedValue
                        if isOpen { open.remove(item.id) } else { open.insert(item.id) }
                        configuration.expanded.wrappedValue = open
                    } label: {
                        HStack(spacing: theme.space.s2) {
                            Text(item.title)
                                .font(theme.type.bodyEmphasis)
                                .foregroundStyle(theme.color.text)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.color.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(Text(isOpen ? "Expanded" : "Collapsed"))
                    if isOpen {
                        Text(item.content)
                            .font(theme.type.footnote)
                            .foregroundStyle(theme.color.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
                .padding(.vertical, theme.space.s2)
                if item.id != configuration.items.last?.id {
                    Rectangle().fill(theme.color.hairline)
                        .frame(height: theme.hairlineWidth(contrast: contrast))
                }
            }
        }
    }
}

extension EnvironmentValues {
    /// The accordion style. Default: `DefaultJRAccordionStyle`.
    @Entry public var jrAccordionStyle: any JRAccordionStyle = DefaultJRAccordionStyle()
}

extension View {
    /// Sets the style of every Accordion in this subtree.
    public func jrAccordionStyle(_ style: some JRAccordionStyle) -> some View {
        environment(\.jrAccordionStyle, style)
    }
}

/// `Accordion`: upstream shadcn props. All sections start closed.
@JRComponent(
    "Accordion",
    description:
        "Collapsible sections. Items as [{title, content}]. Type 'single' (default) or 'multiple'.")
public struct JRAccordion: View {
    @JRProp var items: [JSONValue]
    @JRProp(oneOf: ["single", "multiple"]) var type: String?

    @State private var expanded: Set<Int> = []
    @Environment(\.jrAccordionStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    /// The definition with the `items` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp(
            "items", with: StandardSchemas.objectList([("title", .string), ("content", .string)]))
    }

    public var body: some View {
        let sections = items.enumerated().compactMap { index, value -> JRAccordionItem? in
            guard let title = JRPropDecode.string(value["title"]) else { return nil }
            return JRAccordionItem(
                title: title, content: JRPropDecode.string(value["content"]) ?? "", id: index)
        }
        let mode = type.flatMap(JRAccordionMode.init(rawValue:)) ?? .single
        let binding = Binding<Set<Int>>(
            get: { expanded },
            set: { newValue in
                if mode == .single {
                    let opened = newValue.subtracting(expanded)
                    expanded = opened.isEmpty ? newValue : opened
                } else {
                    expanded = newValue
                }
            })
        let configuration = JRAccordionStyleConfiguration(
            items: sections, mode: mode, expanded: binding, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
