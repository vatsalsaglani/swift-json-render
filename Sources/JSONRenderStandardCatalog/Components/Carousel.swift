// Owner: jr-3b (wave 2). Carousel: a horizontal row of cards with previous / next.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// One carousel card from the `items` prop.
public struct JRCarouselItem: Hashable, Sendable, Identifiable {
    public let id: Int
    public let title: String?
    public let description: String?
}

/// What a carousel style receives: either `items` (cards drawn by the style) or `pages`
/// (the element's children, one per page) when `items` is empty.
public struct JRCarouselStyleConfiguration {
    public let items: [JRCarouselItem]
    public let pages: [JRStyleContent]
    public let theme: JSONRenderTheme
}

/// Restyles every Carousel in a subtree.
public protocol JRCarouselStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRCarouselStyleConfiguration) -> Body
}

/// The default carousel: 220 pt cards with a hairline in a horizontal scroll view that
/// stops on card edges, and previous / next buttons below (no motion under Reduce Motion).
public struct DefaultJRCarouselStyle: JRCarouselStyle {
    public init() {}

    public func makeBody(configuration: JRCarouselStyleConfiguration) -> some View {
        DefaultCarouselBody(configuration: configuration)
    }
}

private struct DefaultCarouselBody: View {
    let configuration: JRCarouselStyleConfiguration
    @State private var position: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var count: Int {
        configuration.items.isEmpty ? configuration.pages.count : configuration.items.count
    }

    var body: some View {
        let theme = configuration.theme
        let current = position ?? 0
        VStack(alignment: .leading, spacing: theme.space.s2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: theme.space.s3) {
                    ForEach(0..<count, id: \.self) { index in
                        page(index)
                            .frame(width: 220, alignment: .topLeading)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                            .id(index)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $position, anchor: .leading)
            if count > 1 {
                HStack(spacing: theme.space.s2) {
                    Button {
                        move(to: current - 1)
                    } label: {
                        Label("Previous", systemImage: "chevron.left").labelStyle(.iconOnly)
                    }
                    .disabled(current <= 0)
                    Text("\(current + 1) of \(count)")
                        .font(theme.type.footnote.monospacedDigit())
                        .foregroundStyle(theme.color.textSecondary)
                    Button {
                        move(to: current + 1)
                    } label: {
                        Label("Next", systemImage: "chevron.right").labelStyle(.iconOnly)
                    }
                    .disabled(current >= count - 1)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    @ViewBuilder
    private func page(_ index: Int) -> some View {
        if configuration.items.isEmpty {
            configuration.pages[index]
        } else {
            itemCard(configuration.items[index])
        }
    }

    private func itemCard(_ item: JRCarouselItem) -> some View {
        let theme = configuration.theme
        return VStack(alignment: .leading, spacing: 4) {
            if let title = item.title {
                Text(title).font(theme.type.bodyEmphasis).foregroundStyle(theme.color.text)
            }
            if let description = item.description {
                Text(description).font(theme.type.footnote)
                    .foregroundStyle(theme.color.textSecondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(theme.space.s3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            theme.color.surface,
            in: RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
        )
        .standardHairline(theme, radius: theme.radius.card)
        .accessibilityElement(children: .combine)
    }

    private func move(to index: Int) {
        let target = min(max(index, 0), max(count - 1, 0))
        if reduceMotion {
            position = target
        } else {
            withAnimation(.easeOut(duration: 0.2)) { position = target }
        }
    }
}

extension EnvironmentValues {
    /// The carousel style. Default: `DefaultJRCarouselStyle`.
    @Entry public var jrCarouselStyle: any JRCarouselStyle = DefaultJRCarouselStyle()
}

extension View {
    /// Sets the style of every Carousel in this subtree.
    public func jrCarouselStyle(_ style: some JRCarouselStyle) -> some View {
        environment(\.jrCarouselStyle, style)
    }
}

/// `Carousel`: upstream shadcn props. When `items` is empty, each child is one page.
@JRComponent(
    "Carousel", description: "Horizontally scrollable carousel of cards.", slots: ["default"])
public struct JRCarousel: View {
    @JRProp var items: [JSONValue]

    @Environment(\.jrCarouselStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    /// The definition with the `items` object list spelled out.
    nonisolated static var catalogDefinition: ComponentDefinition {
        definition.replacingProp("items", with: StandardSchemas.carouselItems)
    }

    public var body: some View {
        let cards = JRCarouselItems.decode(items)
        let configuration = JRCarouselStyleConfiguration(
            items: cards,
            pages: cards.isEmpty
                ? jrContext.children.ids.map { JRStyleContent(JRChildren(ids: [$0])) } : [],
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("Carousel"))
    }
}

/// Decodes `items`: entries with neither a title nor a description are dropped.
enum JRCarouselItems {
    static func decode(_ values: [JSONValue]) -> [JRCarouselItem] {
        values.compactMap { value -> (String?, String?)? in
            let title = value["title"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
            let description = value["description"]?.stringValue.flatMap { $0.isEmpty ? nil : $0 }
            return title == nil && description == nil ? nil : (title, description)
        }
        .enumerated()
        .map { JRCarouselItem(id: $0.offset, title: $0.element.0, description: $0.element.1) }
    }
}
