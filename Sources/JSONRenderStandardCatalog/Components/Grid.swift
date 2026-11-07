// Owner: jr-3 (wave 2). Grid: equal columns.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a grid style receives. `content` is the children as one view list.
public struct JRGridStyleConfiguration {
    /// 1 to 6.
    public let columns: Int
    public let spacing: CGFloat
    public let content: JRStyleContent
    public let isStreaming: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Grid in a subtree.
public protocol JRGridStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRGridStyleConfiguration) -> Body
}

/// The default grid: equal flexible columns, top-aligned cells, the same gap both ways.
public struct DefaultJRGridStyle: JRGridStyle {
    public init() {}

    public func makeBody(configuration: JRGridStyleConfiguration) -> some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: configuration.spacing, alignment: .top),
                count: configuration.columns),
            alignment: .leading, spacing: configuration.spacing
        ) {
            configuration.content
        }
    }
}

extension EnvironmentValues {
    /// The grid style. Default: `DefaultJRGridStyle`.
    @Entry public var jrGridStyle: any JRGridStyle = DefaultJRGridStyle()
}

extension View {
    /// Sets the style of every Grid in this subtree.
    public func jrGridStyle(_ style: some JRGridStyle) -> some View {
        environment(\.jrGridStyle, style)
    }
}

/// `Grid`: upstream shadcn props. One column by default (as upstream); `className` is
/// accepted and ignored.
@JRComponent("Grid", description: "Grid layout (1-6 columns)", slots: ["default"])
public struct JRGrid: View {
    @JRProp var columns: Int?
    @JRProp(oneOf: ["sm", "md", "lg", "xl"]) var gap: String?
    @JRProp(description: "Additional CSS classes") var className: String?

    @Environment(\.jrGridStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let configuration = JRGridStyleConfiguration(
            columns: min(max(columns ?? 1, 1), 6), spacing: StandardGap.points(gap),
            content: JRStyleContent(jrContext.children), isStreaming: jrContext.isStreaming,
            theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
