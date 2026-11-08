// Owner: jr-3 (wave 2). Dialog: a modal sheet bound to state.
public import JSONRenderClient
internal import JSONRenderSwiftUI
public import SwiftUI

/// What a dialog style receives.
public typealias JRDialogStyleConfiguration = JRPresentationStyleConfiguration

/// Restyles every Dialog in a subtree.
public protocol JRDialogStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRDialogStyleConfiguration) -> Body
}

/// The default dialog: title, description, content, then the footer actions and Close.
public struct DefaultJRDialogStyle: JRDialogStyle {
    public init() {}

    public func makeBody(configuration: JRDialogStyleConfiguration) -> some View {
        DefaultPresentationPanel(configuration: configuration, minWidth: 380)
    }
}

extension EnvironmentValues {
    /// The dialog style. Default: `DefaultJRDialogStyle`.
    @Entry public var jrDialogStyle: any JRDialogStyle = DefaultJRDialogStyle()
}

extension View {
    /// Sets the style of every Dialog in this subtree.
    public func jrDialogStyle(_ style: some JRDialogStyle) -> some View {
        environment(\.jrDialogStyle, style)
    }
}

/// `Dialog`: upstream shadcn props plus a bindable `open`.
///
/// Open state: the bound `open` prop when there is one, else the Boolean at `openPath`.
/// Close (and Escape) writes `false` to the same place. Inside another Dialog or Drawer it
/// draws inline with a hairline.
@JRComponent(
    "Dialog",
    description: "Modal dialog. Set openPath to a boolean state path. Use setState to toggle.",
    slots: ["default", "footer"])
public struct JRDialog: View {
    @JRProp var title: String
    @JRProp var description: String?
    @JRProp var openPath: String
    @JRProp(
        description: "Open state as an alternative to openPath. Use { $bindState }.",
        bindable: true)
    var open: Bool?

    @Environment(\.jrDialogStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrRenderModel) private var model
    @Environment(\.jrWriteBinding) private var writeBinding
    @Environment(\.jrInsidePresentation) private var insidePresentation

    public var body: some View {
        let isOpen = jrContext.presentationBinding(
            open: open, openPath: openPath, model: model, writer: writeBinding)
        let configuration = JRDialogStyleConfiguration(
            title: title, description: description,
            content: JRStyleContent(jrContext.children), hasContent: !jrContext.children.isEmpty,
            footer: jrContext.slot(JRSlots.footer).map { JRStyleContent($0) },
            close: { isOpen.wrappedValue = false }, isInline: insidePresentation, theme: theme)
        PresentationHost(
            isOpen: isOpen, isInline: insidePresentation, usesDetents: false, theme: theme
        ) {
            JRStyleContent(style.makeBody(configuration: configuration))
        }
    }
}
