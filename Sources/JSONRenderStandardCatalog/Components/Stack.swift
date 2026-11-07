// Owner: jr-3 (wave 2). Stack: a flex container.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a stack style receives. `content` is the children as one view list: put it in a
/// layout container (`HStack { configuration.content }`) and each child is one subview.
public struct JRStackStyleConfiguration {
    public let axis: Axis
    public let spacing: CGFloat
    public let align: JRStackAlign
    public let justify: JRStackJustify
    public let wrap: Bool
    public let content: JRStyleContent
    public let isStreaming: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Stack in a subtree.
public protocol JRStackStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRStackStyleConfiguration) -> Body
}

/// The default stack: the flex layout with the spec's gap (none 0, sm 6, md 10, lg 16,
/// xl 20), alignment (default start) and justification. A horizontal stack wraps onto new
/// lines unless the spec sets `wrap: false` (upstream uses `flex-wrap`).
public struct DefaultJRStackStyle: JRStackStyle {
    public init() {}

    public func makeBody(configuration: JRStackStyleConfiguration) -> some View {
        FlexLayout(
            axis: configuration.axis, spacing: configuration.spacing, align: configuration.align,
            justify: configuration.justify, wrap: configuration.wrap
        ) {
            configuration.content
        }
    }
}

extension EnvironmentValues {
    /// The stack style. Default: `DefaultJRStackStyle`.
    @Entry public var jrStackStyle: any JRStackStyle = DefaultJRStackStyle()
}

extension View {
    /// Sets the style of every Stack in this subtree.
    public func jrStackStyle(_ style: some JRStackStyle) -> some View {
        environment(\.jrStackStyle, style)
    }
}

/// `Stack`: upstream shadcn props plus `wrap`. `className` is accepted and ignored.
@JRComponent("Stack", description: "Flex container for layouts", slots: ["default"])
public struct JRStack: View {
    @JRProp(oneOf: ["horizontal", "vertical"]) var direction: String?
    @JRProp(oneOf: ["none", "sm", "md", "lg", "xl"]) var gap: String?
    @JRProp(oneOf: ["start", "center", "end", "stretch"]) var align: String?
    @JRProp(oneOf: ["start", "center", "end", "between", "around"]) var justify: String?
    @JRProp(description: "Additional CSS classes") var className: String?
    @JRProp(
        description: "A horizontal stack flows its children onto new lines (default true).")
    var wrap: Bool?

    @Environment(\.jrStackStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let configuration = JRStackStyleConfiguration(
            axis: direction == "horizontal" ? .horizontal : .vertical,
            spacing: StandardGap.points(gap),
            align: align.flatMap(JRStackAlign.init(rawValue:)) ?? .start,
            justify: justify.flatMap(JRStackJustify.init(rawValue:)) ?? .start,
            wrap: wrap ?? true, content: JRStyleContent(jrContext.children),
            isStreaming: jrContext.isStreaming, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
