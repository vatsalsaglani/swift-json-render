// Owner: jr-3 (wave 2). Shared open-state and presentation for Dialog and Drawer.
internal import JSONRenderCore
public import JSONRenderSwiftUI
public import SwiftUI

/// What a Dialog or Drawer style receives. `close` sets the open state to `false`.
public struct JRPresentationStyleConfiguration {
    public let title: String
    public let description: String?
    public let content: JRStyleContent
    public let hasContent: Bool
    /// The `footer` slot (action buttons).
    public let footer: JRStyleContent?
    public let close: @MainActor () -> Void
    /// `true` when drawn inline (inside another presentation, or in a preview).
    public let isInline: Bool
    public let theme: JSONRenderTheme
}

/// The default panel: a 15 pt title, a 12 pt description, the content, then the footer
/// actions and a Close button (Escape) at the trailing edge.
struct DefaultPresentationPanel: View {
    let configuration: JRPresentationStyleConfiguration
    let minWidth: CGFloat

    var body: some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: theme.space.s3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.title)
                    .font(theme.type.title)
                    .foregroundStyle(theme.color.text)
                    .accessibilityAddTraits(.isHeader)
                if let description = configuration.description {
                    Text(description)
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.color.textSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            if configuration.hasContent { configuration.content }
            HStack(spacing: theme.space.s2) {
                Spacer(minLength: 0)
                if let footer = configuration.footer { footer }
                Button("Close") { configuration.close() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(theme.space.s5)
        .frame(minWidth: configuration.isInline ? nil : minWidth, alignment: .leading)
        .background(theme.color.surface)
    }
}

/// Presents `panel` in a sheet bound to `isOpen`, or draws it inline (hairline box) inside
/// another presentation: macOS cannot stack a sheet on a sheet from one view tree.
struct PresentationHost<Panel: View>: View {
    let isOpen: Binding<Bool>
    let isInline: Bool
    let usesDetents: Bool
    let theme: JSONRenderTheme
    @ViewBuilder let panel: Panel

    var body: some View {
        if isInline {
            if isOpen.wrappedValue {
                panel.clipShape(
                    RoundedRectangle(cornerRadius: theme.radius.card, style: .continuous)
                )
                .standardHairline(theme, radius: theme.radius.card)
            }
        } else {
            Color.clear
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
                .sheet(isPresented: isOpen) {
                    panel
                        .environment(\.jrInsidePresentation, true)
                        .presentationDetentsIfAvailable(usesDetents)
                }
        }
    }
}

extension View {
    @ViewBuilder
    fileprivate func presentationDetentsIfAvailable(_ enabled: Bool) -> some View {
        #if os(iOS)
            if enabled {
                presentationDetents([.medium, .large])
            } else {
                self
            }
        #else
            self
        #endif
    }
}

extension JRRenderContext {
    /// The open state of a Dialog or Drawer: the bound `open` prop when there is one, else
    /// the Boolean at `openPath` in state. Setting it writes the same place.
    @MainActor
    func presentationBinding(
        open: Bool?, openPath: String, model: RenderModel?, writer: JRBindingWriter
    ) -> Binding<Bool> {
        let pointer = try? JSONPointer(openPath)
        let bound = isBound("open")
        let current: Bool =
            bound
            ? (open ?? false)
            : pointer.flatMap { model?.stateSnapshot.state.value(at: $0)?.isTruthy } ?? false
        return Binding(
            get: { current },
            set: { newValue in
                if writeBound("open", .bool(newValue), with: writer) { return }
                if let pointer, !pointer.isRoot { writer(pointer, .bool(newValue)) }
            })
    }
}
