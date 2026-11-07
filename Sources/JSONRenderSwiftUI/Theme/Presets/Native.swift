// Owner: jr-3 (wave 2); seeded by jr-1b. VPLAN section 2.3 token values.
internal import SwiftUI

#if canImport(AppKit)
    internal import AppKit
#elseif canImport(UIKit)
    internal import UIKit
#endif

extension JSONRenderTheme {
    /// The default preset: system colours, the macOS type ramp (11 / 12 / 13 / 15 / 20 pt),
    /// spacing 4 / 8 / 12 / 16 / 20 / 32, radii 7 / 8 / 12, no card shadow, a 180 ms reveal.
    ///
    /// Secondary and muted text are system-like greys tuned to pass `validated()`: the
    /// system `secondaryLabelColor` measures 3.95:1 on white, below the 4.5:1 text rule.
    public static let native = JSONRenderTheme(
        color: ColorRoles(
            surface: SystemColor.windowBackground,
            surfaceRaised: SystemColor.controlBackground,
            text: SystemColor.label,
            textSecondary: DynamicColor.ink(light: 0.62, dark: 0.62),
            textMuted: DynamicColor.ink(light: 0.50, dark: 0.45),
            hairline: SystemColor.separator,
            accent: SystemColor.accent,
            onAccent: .white,
            good: SystemColor.green,
            warning: SystemColor.orange,
            critical: SystemColor.red,
            info: SystemColor.blue,
            focus: SystemColor.accent),
        type: .native,
        space: SpaceScale(s1: 4, s2: 8, s3: 12, s4: 16, s5: 20, s6: 32),
        radius: RadiusScale(control: 7, field: 8, card: 12),
        elevation: Elevation(cardShadowRadius: 8, cardShadowY: 2, cardShadowOpacity: 0.10),
        motion: Motion(reveal: .milliseconds(180), pulse: .milliseconds(1200)),
        charts: .defaults(role: .native))
}

extension TypeScale {
    /// The native ramp. macOS has no Dynamic Type; sizes follow the 13 pt system body.
    static let native: TypeScale = {
        #if os(macOS)
            TypeScale(
                caption: .system(size: 11), footnote: .system(size: 12), body: .system(size: 13),
                bodyEmphasis: .system(size: 13, weight: .semibold),
                title: .system(size: 15, weight: .semibold),
                display: .system(size: 20, weight: .semibold),
                mono: .system(size: 12, design: .monospaced),
                weights: TypeScale.Weights(regular: .regular, medium: .medium, semibold: .semibold))
        #else
            TypeScale(
                caption: .caption, footnote: .footnote, body: .body,
                bodyEmphasis: .body.weight(.semibold), title: .headline,
                display: .title2.weight(.semibold), mono: .footnote.monospaced(),
                weights: TypeScale.Weights(regular: .regular, medium: .medium, semibold: .semibold))
        #endif
    }()
}

extension Motion {
    /// No motion: the value Reduce Motion selects.
    public static let none = Motion(reveal: .zero, pulse: .zero)
}

/// The platform's semantic colours.
enum SystemColor {
    #if canImport(AppKit)
        static let windowBackground = Color(nsColor: .windowBackgroundColor)
        static let controlBackground = Color(nsColor: .controlBackgroundColor)
        static let label = Color(nsColor: .labelColor)
        static let separator = Color(nsColor: .separatorColor)
        static let accent = Color(nsColor: .controlAccentColor)
        static let green = Color(nsColor: .systemGreen)
        static let orange = Color(nsColor: .systemOrange)
        static let red = Color(nsColor: .systemRed)
        static let blue = Color(nsColor: .systemBlue)
    #elseif canImport(UIKit)
        static let windowBackground = Color(uiColor: .systemBackground)
        static let controlBackground = Color(uiColor: .secondarySystemBackground)
        static let label = Color(uiColor: .label)
        static let separator = Color(uiColor: .separator)
        static let accent = Color.accentColor
        static let green = Color(uiColor: .systemGreen)
        static let orange = Color(uiColor: .systemOrange)
        static let red = Color(uiColor: .systemRed)
        static let blue = Color(uiColor: .systemBlue)
    #else
        static let windowBackground = Color.white
        static let controlBackground = Color.white
        static let label = Color.black
        static let separator = Color.gray
        static let accent = Color.blue
        static let green = Color.green
        static let orange = Color.orange
        static let red = Color.red
        static let blue = Color.blue
    #endif
}
