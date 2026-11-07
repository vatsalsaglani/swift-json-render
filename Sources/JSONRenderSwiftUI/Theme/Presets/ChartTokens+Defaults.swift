// Owner: jr-3 (wave 2); seeded by jr-1b. jr-3c may tune values, not move them out of this target.
internal import SwiftUI

extension ChartTokens {
    /// The default chart tokens every preset includes.
    ///
    /// - `categorical`: eight hues spaced for colour-vision deficiencies (Okabe–Ito order).
    /// - `sequential`: five steps of one blue, light to dark.
    /// - `diverging`: five steps, orange through neutral grey to blue.
    ///
    /// Charts never rely on colour alone: series also carry labels, legends or patterns.
    public static let standard = ChartTokens(
        categorical: [
            hex(0x0072B2), hex(0xE69F00), hex(0x009E73), hex(0xCC79A7),
            hex(0x56B4E9), hex(0xD55E00), hex(0xF0E442), hex(0x7F7F7F),
        ],
        sequential: [hex(0xDEEBF7), hex(0x9ECAE1), hex(0x6BAED6), hex(0x3182BD), hex(0x08519C)],
        diverging: [hex(0xD55E00), hex(0xF4A582), hex(0xBDBDBD), hex(0x92C5DE), hex(0x0072B2)],
        gridline: Color.secondary.opacity(0.25),
        axisFont: .caption2,
        barCornerRadius: 3,
        lineWidth: 2,
        pointSize: 36,
        gaugeTrackWidth: 10,
        sliceGap: 1.5)

    private static func hex(_ value: UInt32) -> Color {
        Color(
            .sRGB, red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
