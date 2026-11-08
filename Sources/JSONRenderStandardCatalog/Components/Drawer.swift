// Owner: jr-3 (wave 2). Drawer: a sheet (iOS: medium and large detents) bound to state.
public import JSONRenderClient
internal import JSONRenderSwiftUI
public import SwiftUI

/// What a drawer style receives.
public typealias JRDrawerStyleConfiguration = JRPresentationStyleConfiguration

/// Restyles every Drawer in a subtree.
public protocol JRDrawerStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRDrawerStyleConfiguration) -> Body
}

/// The default drawer: title, description, content, then the footer actions and Close.
public struct DefaultJRDrawerStyle: JRDrawerStyle {
    public init() {}

    public func makeBody(configuration: JRDrawerStyleConfiguration) -> some View {
        DefaultPresentationPanel(configuration: configuration, minWidth: 440)
    }
}

extension EnvironmentValues {
    /// The drawer style. Default: `DefaultJRDrawerStyle`.
    @Entry public var jrDrawerStyle: any JRDrawerStyle = DefaultJRDrawerStyle()
}

extension View {
    /// Sets the style of every Drawer in this subtree.
    public func jrDrawerStyle(_ style: some JRDrawerStyle) -> some View {
        environment(\.jrDrawerStyle, style)
    }
}

/// `Drawer`: upstream shadcn props plus a bindable `open`.
///
/// Open state: the bound `open` prop when there is one, else the Boolean at `openPath`.
/// Close (and Escape) writes `false` to the same place. Inside another Dialog or Drawer it
/// draws inline with a hairline.
@JRComponent(
    "Drawer",
    description:
        "Bottom sheet drawer. Set openPath to a boolean state path. Use setState to toggle.",
    slots: ["default", "footer"])
public struct JRDrawer: View {
    @JRProp var title: String
    @JRProp var description: String?
    @JRProp var openPath: String
    @JRProp(
        description: "Open state as an alternative to openPath. Use { $bindState }.",
        bindable: true)
    var open: Bool?

    @Environment(\.jrDrawerStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrRenderModel) private var model
    @Environment(\.jrWriteBinding) private var writeBinding
    @Environment(\.jrInsidePresentation) private var insidePresentation

    public var body: some View {
        let isOpen = jrContext.presentationBinding(
            open: open, openPath: openPath, model: model, writer: writeBinding)
        let configuration = JRDrawerStyleConfiguration(
            title: title, description: description,
            content: JRStyleContent(jrContext.children), hasContent: !jrContext.children.isEmpty,
            footer: jrContext.slot(JRSlots.footer).map { JRStyleContent($0) },
            close: { isOpen.wrappedValue = false }, isInline: insidePresentation, theme: theme)
        PresentationHost(
            isOpen: isOpen, isInline: insidePresentation, usesDetents: true, theme: theme
        ) {
            JRStyleContent(style.makeBody(configuration: configuration))
        }
    }
}
