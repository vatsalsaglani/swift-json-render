// Owner: jr-3b (wave 2). Spinner: an indeterminate activity indicator.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a spinner style receives.
public struct JRSpinnerStyleConfiguration {
    public let label: String?
    /// `nil` keeps the inherited control size.
    public let controlSize: ControlSize?
    /// `true` under Reduce Motion: draw something that does not move.
    public let reducesMotion: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Spinner in a subtree.
public protocol JRSpinnerStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRSpinnerStyleConfiguration) -> Body
}

/// The default spinner: the small native circular indicator and the label. Under Reduce
/// Motion a static hourglass symbol replaces the indicator.
public struct DefaultJRSpinnerStyle: JRSpinnerStyle {
    public init() {}

    public func makeBody(configuration: JRSpinnerStyleConfiguration) -> some View {
        let theme = configuration.theme
        HStack(spacing: theme.space.s2) {
            if configuration.reducesMotion {
                Image(systemName: "hourglass")
                    .foregroundStyle(theme.color.textSecondary)
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(configuration.controlSize ?? .small)
            }
            if let label = configuration.label {
                Text(label).font(theme.type.footnote).foregroundStyle(theme.color.textSecondary)
            }
        }
    }
}

extension EnvironmentValues {
    /// The spinner style. Default: `DefaultJRSpinnerStyle`.
    @Entry public var jrSpinnerStyle: any JRSpinnerStyle = DefaultJRSpinnerStyle()
}

extension View {
    /// Sets the style of every Spinner in this subtree.
    public func jrSpinnerStyle(_ style: some JRSpinnerStyle) -> some View {
        environment(\.jrSpinnerStyle, style)
    }
}

/// `Spinner`: upstream shadcn props. VoiceOver reads the label (or "Loading").
@JRComponent("Spinner", description: "Loading spinner indicator")
public struct JRSpinner: View {
    @JRProp(oneOf: ["sm", "md", "lg"]) var size: String?
    @JRProp var label: String?

    @Environment(\.jrSpinnerStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public var body: some View {
        let label = label.flatMap { $0.isEmpty ? nil : $0 }
        let configuration = JRSpinnerStyleConfiguration(
            label: label, controlSize: JRControlSize.controlSize(for: size),
            reducesMotion: reduceMotion, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label ?? "Loading"))
            .accessibilityAddTraits(.updatesFrequently)
    }
}
