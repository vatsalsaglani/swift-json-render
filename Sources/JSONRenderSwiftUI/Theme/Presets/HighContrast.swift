// Owner: jr-3 (wave 2).
internal import SwiftUI

extension JSONRenderTheme {
    /// Stronger text and an opaque hairline that draws at 2 pt; on-accent text is black or
    /// white, whichever has more contrast with the user's accent colour. Status hues stay
    /// the system colours: the platform already swaps in its high-contrast variants when
    /// the user turns on Increase Contrast, and the package has no other variant to use.
    public static let highContrast = JSONRenderTheme(
        color: ColorRoles(
            surface: SystemColor.windowBackground,
            surfaceRaised: SystemColor.controlBackground,
            text: DynamicColor.ink(light: 1, dark: 1),
            textSecondary: DynamicColor.ink(light: 0.78, dark: 0.80),
            textMuted: DynamicColor.ink(light: 0.78, dark: 0.80),
            hairline: highContrastHairline,
            accent: SystemColor.accent,
            onAccent: DynamicColor.onAccent(),
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
        charts: .defaults(role: .highContrast))

    /// The opaque hairline of `.highContrast`. A theme whose hairline is this colour draws
    /// hairlines at 2 pt (see `hairlineWidth(contrast:)`).
    static let highContrastHairline = DynamicColor.grey(light: 0.45, dark: 0.62)
}
