// Owner: jr-3b (wave 2). Slider: a number in a range.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a slider style receives. `range` is `min...max` (max is raised to min when it is
/// lower); `step` is positive. Setting `value` snaps it to the step, writes the bound
/// `value` and emits `change`.
public struct JRSliderStyleConfiguration {
    public let label: String?
    public let value: Binding<Double>
    public let range: ClosedRange<Double>
    public let step: Double
    /// The value as text (tabular digits), for example "40".
    public let valueText: String
    public let theme: JSONRenderTheme
}

/// Restyles every Slider in a subtree.
public protocol JRSliderStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRSliderStyleConfiguration) -> Body
}

/// The default slider: the label and the value on one line, the native slider below.
public struct DefaultJRSliderStyle: JRSliderStyle {
    public init() {}

    public func makeBody(configuration: JRSliderStyleConfiguration) -> some View {
        let theme = configuration.theme
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let label = configuration.label {
                    Text(label).font(theme.type.footnote.weight(theme.type.weights.medium))
                        .foregroundStyle(theme.color.textSecondary)
                }
                Spacer(minLength: theme.space.s2)
                Text(configuration.valueText)
                    .font(theme.type.footnote.monospacedDigit())
                    .foregroundStyle(theme.color.textSecondary)
            }
            .accessibilityHidden(true)
            // No `step:` here: AppKit would draw one tick per step. The value snaps instead.
            Slider(value: configuration.value, in: configuration.range)
                .labelsHidden()
                .accessibilityLabel(Text(configuration.label ?? "Slider"))
                .accessibilityValue(Text(configuration.valueText))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension EnvironmentValues {
    /// The slider style. Default: `DefaultJRSliderStyle`.
    @Entry public var jrSliderStyle: any JRSliderStyle = DefaultJRSliderStyle()
}

extension View {
    /// Sets the style of every Slider in this subtree.
    public func jrSliderStyle(_ style: some JRSliderStyle) -> some View {
        environment(\.jrSliderStyle, style)
    }
}

/// `Slider`: upstream shadcn props. Defaults: `min` 0, `max` 100, `step` 1.
@JRComponent(
    "Slider", description: "Range slider input. Use { $bindState } on value for binding.",
    events: ["change"])
public struct JRSlider: View {
    @JRProp var label: String?
    @JRProp var min: Double?
    @JRProp var max: Double?
    @JRProp var step: Double?
    @JRProp(bindable: true) var value: Double?

    @State private var localValue: Double?
    @Environment(\.jrSliderStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.jrWriteBinding) private var writeBinding

    public var body: some View {
        let context = jrContext
        let range = JRSliderMath.range(min: min, max: max)
        let step = JRSliderMath.step(step)
        let raw = context.isBound("value") ? value : (localValue ?? value)
        let current = Swift.min(
            Swift.max(raw ?? range.lowerBound, range.lowerBound), range.upperBound)
        let binding = Binding<Double>(
            get: { current },
            set: { proposed in
                let newValue = JRSliderMath.snap(proposed, range: range, step: step)
                guard newValue != current else { return }
                if !context.writeBound("value", .number(newValue), with: writeBinding) {
                    localValue = newValue
                }
                context.emit("change", [:])
            })
        let configuration = JRSliderStyleConfiguration(
            label: label.flatMap { $0.isEmpty ? nil : $0 }, value: binding, range: range,
            step: step, valueText: JSONValue.number(current).jsString, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}

/// Range and step rules, pure for tests.
enum JRSliderMath {
    /// `min...max`, defaults 0 and 100; a non-finite bound takes its default; `max` below
    /// `min` becomes `min + 1`.
    static func range(min: Double?, max: Double?) -> ClosedRange<Double> {
        let low = min.flatMap { $0.isFinite ? $0 : nil } ?? 0
        let high = max.flatMap { $0.isFinite ? $0 : nil } ?? 100
        return low...(high > low ? high : low + 1)
    }

    /// `value` rounded to the nearest step from the lower bound, inside `range`.
    static func snap(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let steps = ((value - range.lowerBound) / step).rounded()
        let snapped = range.lowerBound + steps * step
        return Swift.min(Swift.max(snapped, range.lowerBound), range.upperBound)
    }

    /// A positive finite step, default 1.
    static func step(_ step: Double?) -> Double {
        guard let step, step.isFinite, step > 0 else { return 1 }
        return step
    }
}
