public import JSONRenderSwiftUI
public import SwiftUI

/// Colour lookups for one chart: one hue for one series, the categorical palette for
/// series, status colours only for a status, grey for "Other".
public struct ChartColors {
    public let tokens: ChartTokens
    public let roles: ColorRoles

    public init(theme: JSONRenderTheme) {
        tokens = theme.charts
        roles = theme.color
    }

    /// The colour of a one-series chart: the accent.
    public var single: Color { roles.accent }

    /// The grey of the folded "Other" value and of totals.
    public var other: Color { roles.textMuted.opacity(0.55) }

    /// The colour of series `index` (the palette cycles after eight).
    public func series(_ index: Int) -> Color {
        guard !tokens.categorical.isEmpty else { return roles.accent }
        return tokens.categorical[index % tokens.categorical.count]
    }

    /// The palette for `names`, in order.
    public func palette(for names: [String]) -> [Color] {
        names.indices.map(series)
    }

    /// The status colour for `intent`; the hairline colour for none.
    public func intent(_ intent: ChartIntent?) -> Color {
        switch intent {
        case .good?: roles.good
        case .warning?: roles.warning
        case .critical?: roles.critical
        case .info?: roles.info
        case nil: roles.textSecondary
        }
    }

    /// The stroke for series `index`: solid for the first eight, then dashed, so colour is
    /// not the only difference when the palette cycles.
    public func stroke(_ index: Int) -> StrokeStyle {
        let dashes: [[CGFloat]] = [[], [5, 3], [2, 2], [8, 3, 2, 3]]
        let pattern = dashes[(index / max(tokens.categorical.count, 1)) % dashes.count]
        return StrokeStyle(lineWidth: tokens.lineWidth, lineCap: .round, dash: pattern)
    }

    /// A sequential colour for `fraction` in 0...1.
    public func sequential(_ fraction: Double) -> Color {
        ramp(tokens.sequential, fraction)
    }

    /// A diverging colour for `fraction` in 0...1 (0.5 is the midpoint).
    public func diverging(_ fraction: Double) -> Color {
        ramp(tokens.diverging, fraction)
    }

    private func ramp(_ colors: [Color], _ fraction: Double) -> Color {
        guard !colors.isEmpty else { return roles.accent }
        let clamped = min(max(fraction.isFinite ? fraction : 0, 0), 1)
        let index = Int((clamped * Double(colors.count - 1)).rounded())
        return colors[index]
    }
}
