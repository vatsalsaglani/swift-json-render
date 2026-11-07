// Owner: jr-3 (wave 2). Popover: a button that shows text in a popover.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a popover style receives. `isPresented` shows and hides the popover.
public struct JRPopoverStyleConfiguration {
    public let trigger: String
    public let content: String
    public let isPresented: Binding<Bool>
    public let theme: JSONRenderTheme
}

/// Restyles every Popover in a subtree.
public protocol JRPopoverStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRPopoverStyleConfiguration) -> Body
}

/// The default popover: a bordered button; the text at 13 pt in a 280 pt wide popover.
public struct DefaultJRPopoverStyle: JRPopoverStyle {
    public init() {}

    public func makeBody(configuration: JRPopoverStyleConfiguration) -> some View {
        let theme = configuration.theme
        Button(configuration.trigger) {
            configuration.isPresented.wrappedValue.toggle()
        }
        .buttonStyle(.bordered)
        .popover(isPresented: configuration.isPresented, arrowEdge: .bottom) {
            Text(configuration.content)
                .font(theme.type.body)
                .foregroundStyle(theme.color.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 280, alignment: .leading)
                .padding(theme.space.s3)
                .textSelection(.enabled)
        }
    }
}

extension EnvironmentValues {
    /// The popover style. Default: `DefaultJRPopoverStyle`.
    @Entry public var jrPopoverStyle: any JRPopoverStyle = DefaultJRPopoverStyle()
}

extension View {
    /// Sets the style of every Popover in this subtree.
    public func jrPopoverStyle(_ style: some JRPopoverStyle) -> some View {
        environment(\.jrPopoverStyle, style)
    }
}

/// `Popover`: upstream shadcn props. The open state is view state.
@JRComponent("Popover", description: "Popover that appears on click of trigger.")
public struct JRPopover: View {
    @JRProp var trigger: String
    @JRProp var content: String

    @State private var isPresented = false
    @Environment(\.jrPopoverStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let configuration = JRPopoverStyleConfiguration(
            trigger: trigger, content: content, isPresented: $isPresented, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}
