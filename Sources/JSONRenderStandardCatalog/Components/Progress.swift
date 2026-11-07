// Owner: jr-3b (wave 2). Progress: a determinate bar with a label and a percentage.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a progress style receives. `value` is clamped to `0...total`.
public struct JRProgressStyleConfiguration {
    public let label: String?
    public let value: Double
    public let total: Double
    /// The rounded percentage, for example "72 %".
    public let percentText: String
    public let theme: JSONRenderTheme
}

/// Restyles every Progress in a subtree.
public protocol JRProgressStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRProgressStyleConfiguration) -> Body
}

/// The default progress: the label and the percentage (tabular digits) on one line, a
/// thin native bar in the accent below.
public struct DefaultJRProgressStyle: JRProgressStyle {
    public init() {}

    public func makeBody(configuration: JRProgressStyleConfiguration) -> some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let label = configuration.label {
                    Text(label).font(theme.type.footnote)
                        .foregroundStyle(theme.color.textSecondary)
                }
                Spacer(minLength: theme.space.s2)
                Text(configuration.percentText)
                    .font(theme.type.footnote.monospacedDigit())
                    .foregroundStyle(theme.color.textSecondary)
            }
            ProgressView(value: configuration.value, total: configuration.total)
                .progressViewStyle(.linear)
                .tint(theme.color.accent)
                .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EnvironmentValues {
    /// The progress style. Default: `DefaultJRProgressStyle`.
    @Entry public var jrProgressStyle: any JRProgressStyle = DefaultJRProgressStyle()
}

extension View {
    /// Sets the style of every Progress in this subtree.
    public func jrProgressStyle(_ style: some JRProgressStyle) -> some View {
        environment(\.jrProgressStyle, style)
    }
}

/// `Progress`: upstream shadcn props. `max` defaults to 100.
@JRComponent("Progress", description: "Progress bar (value 0-100)")
public struct JRProgress: View {
    @JRProp var value: Double
    @JRProp var max: Double?
    @JRProp var label: String?

    @Environment(\.jrProgressStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let measure = JRProgressMeasure(value: value, max: max)
        let label = label.flatMap { $0.isEmpty ? nil : $0 }
        let configuration = JRProgressStyleConfiguration(
            label: label, value: measure.value, total: measure.total,
            percentText: "\(measure.percent) %", theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label ?? "Progress"))
            .accessibilityValue(Text("\(measure.percent) percent"))
    }
}

/// The clamped value and the percentage, pure for tests.
struct JRProgressMeasure: Equatable {
    let value: Double
    let total: Double
    let percent: Int

    /// A missing, zero, negative or non-finite `max` is 100; `value` is clamped to
    /// `0...total`; a non-finite value is 0.
    init(value: Double, max: Double?) {
        let total = max.flatMap { $0.isFinite && $0 > 0 ? $0 : nil } ?? 100
        let clamped = value.isFinite ? Swift.min(Swift.max(value, 0), total) : 0
        self.value = clamped
        self.total = total
        self.percent = Int((clamped / total * 100).rounded())
    }
}
