// Owner: jr-3 (wave 2); seeded by jr-1b. jr-3c may tune values, not move them out of this target.
internal import SwiftUI

#if canImport(AppKit)
    internal import AppKit
#elseif canImport(UIKit)
    internal import UIKit
#endif

extension ChartTokens {
    /// The default chart tokens every preset includes.
    ///
    /// - `categorical`: eight hues, Okabe–Ito order, adapted per appearance (jr-3c). Each
    ///   colour has a contrast of at least 4.2:1 against a white card (light) and 5.9:1
    ///   against `#1E1E1E` (dark). Neighbours differ by CIE76 ΔE ≥ 29, and by ΔE ≥ 23 on a
    ///   protanopia-simulated copy (Viénot 1999). `JSONRenderCharts` tests both checks.
    /// - `sequential`: five steps of one blue; low values are close to the card colour.
    /// - `diverging`: five steps, orange through neutral grey to blue.
    /// - `pointSize` is the point diameter in points; `lineWidth` and `gaugeTrackWidth` are
    ///   stroke widths in points; `sliceGap` is the angular inset of pie slices in points.
    ///
    /// Charts never rely on colour alone: series also carry labels, legends or patterns.
    public static let standard = ChartTokens(
        categorical: [
            adaptive(0x0072B2, 0x4DA3E0), adaptive(0xC85A00, 0xF0A030),
            adaptive(0x00805D, 0x2FBF8F), adaptive(0xB3407F, 0xE58AC0),
            adaptive(0x6A51A3, 0xA98BE0), adaptive(0x8C6D00, 0xD9C43A),
            adaptive(0x2A7FA8, 0x6FD0F0), adaptive(0x6B6B6B, 0xA6A6A6),
        ],
        sequential: [
            adaptive(0xDEEBF7, 0x16324F), adaptive(0x9ECAE1, 0x1F5A8C),
            adaptive(0x6BAED6, 0x2F7FC1), adaptive(0x3182BD, 0x5AA5E0),
            adaptive(0x08519C, 0x9DCBF2),
        ],
        diverging: [
            adaptive(0xC85A00, 0xF0A030), adaptive(0xF4A582, 0x9A5A2E),
            adaptive(0xBDBDBD, 0x5A5A5A), adaptive(0x92C5DE, 0x2E6A90),
            adaptive(0x0072B2, 0x4DA3E0),
        ],
        gridline: Color.secondary.opacity(0.25),
        axisFont: .caption2.monospacedDigit(),
        barCornerRadius: 3,
        lineWidth: 2,
        pointSize: 6,
        gaugeTrackWidth: 10,
        sliceGap: 1.5)

    /// A colour that takes `light` in a light appearance and `dark` in a dark one.
    private static func adaptive(_ light: UInt32, _ dark: UInt32) -> Color {
        #if canImport(AppKit)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    let isDark =
                        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                    return platform(isDark ? dark : light)
                })
        #elseif canImport(UIKit)
            Color(
                uiColor: UIColor { traits in
                    platform(traits.userInterfaceStyle == .dark ? dark : light)
                })
        #else
            hex(light)
        #endif
    }

    #if canImport(AppKit)
        private static func platform(_ value: UInt32) -> NSColor {
            NSColor(
                srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255,
                alpha: 1)
        }
    #elseif canImport(UIKit)
        private static func platform(_ value: UInt32) -> UIColor {
            UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255, blue: CGFloat(value & 0xFF) / 255,
                alpha: 1)
        }
    #endif

    private static func hex(_ value: UInt32) -> Color {
        Color(
            .sRGB, red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255)
    }
}
