// Owner: jr-3 (wave 2). Pagination: previous, "Page n of m", next.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a pagination style receives. Pages are 1-based; `page` is clamped to
/// `1...totalPages`. Setting it writes the bound `page` and emits `change`.
public struct JRPaginationStyleConfiguration {
    public let page: Binding<Int>
    public let totalPages: Int
    public let theme: JSONRenderTheme
}

/// Restyles every Pagination in a subtree.
public protocol JRPaginationStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRPaginationStyleConfiguration) -> Body
}

/// The default pagination: two borderless buttons around a tabular "Page n of m". Left and
/// right arrows move when it has keyboard focus.
public struct DefaultJRPaginationStyle: JRPaginationStyle {
    public init() {}

    public func makeBody(configuration: JRPaginationStyleConfiguration) -> some View {
        let theme = configuration.theme
        let page = configuration.page.wrappedValue
        let total = configuration.totalPages
        HStack(spacing: theme.space.s3) {
            Button {
                configuration.page.wrappedValue = page - 1
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(page <= 1)
            Text("Page \(page) of \(total)")
                .font(theme.type.footnote.monospacedDigit())
                .foregroundStyle(theme.color.textSecondary)
            Button {
                configuration.page.wrappedValue = page + 1
            } label: {
                Label("Next", systemImage: "chevron.right")
                    .labelStyle(TrailingIconLabelStyle())
            }
            .disabled(page >= total)
        }
        .buttonStyle(.borderless)
        .font(theme.type.body)
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .left: if page > 1 { configuration.page.wrappedValue = page - 1 }
            case .right: if page < total { configuration.page.wrappedValue = page + 1 }
            default: break
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Pagination"))
    }
}

/// Title first, then the icon.
private struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

extension EnvironmentValues {
    /// The pagination style. Default: `DefaultJRPaginationStyle`.
    @Entry public var jrPaginationStyle: any JRPaginationStyle = DefaultJRPaginationStyle()
}

extension View {
    /// Sets the style of every Pagination in this subtree.
    public func jrPaginationStyle(_ style: some JRPaginationStyle) -> some View {
        environment(\.jrPaginationStyle, style)
    }
}

/// `Pagination`: upstream shadcn props. An unbound `page` is kept in view state.
@JRComponent(
    "Pagination",
    description: "Page navigation. Use { $bindState } on page for current page number.",
    events: ["change"])
public struct JRPagination: View {
    @JRProp var totalPages: Int
    @JRProp(bindable: true) var page: Int?

    @State private var localPage: Int?
    @Environment(\.jrPaginationStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    public var body: some View {
        let total = max(totalPages, 1)
        let current = min(max((jrContext.isBound("page") ? page : localPage ?? page) ?? 1, 1), total)
        let binding = Binding<Int>(
            get: { current },
            set: { newValue in
                let clamped = min(max(newValue, 1), total)
                guard clamped != current else { return }
                if !jrContext.writeBound("page", .number(Double(clamped)), with: writeBinding) {
                    localPage = clamped
                }
                jrContext.emit("change", ["page": .number(Double(clamped))])
            })
        let configuration = JRPaginationStyleConfiguration(
            page: binding, totalPages: total, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
