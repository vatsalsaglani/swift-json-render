// Owner: jr-3 (wave 2); seeded by jr-1b with system-adaptive values. jr-3 refines them.
internal import SwiftUI

#if canImport(AppKit)
    internal import AppKit
#elseif canImport(UIKit)
    internal import UIKit
#endif

extension JSONRenderTheme {
    /// The default preset: system colours and fonts, so it follows light and dark mode,
    /// Increase Contrast and Dynamic Type.
    public static let native = JSONRenderTheme(
        color: ColorRoles(
            surface: platformColor(.surface),
            surfaceRaised: platformColor(.raised),
            text: .primary,
            textSecondary: .secondary,
            textMuted: Color.secondary.opacity(0.8),
            hairline: platformColor(.separator),
            accent: .accentColor,
            onAccent: .white,
            good: .green,
            warning: .orange,
            critical: .red,
            info: .blue,
            focus: .accentColor),
        type: TypeScale(
            caption: .caption, footnote: .footnote, body: .body,
            bodyEmphasis: .body.weight(.semibold), title: .title3.weight(.semibold),
            display: .largeTitle.weight(.semibold), mono: .body.monospaced(),
            weights: TypeScale.Weights(regular: .regular, medium: .medium, semibold: .semibold)),
        space: SpaceScale(s1: 4, s2: 8, s3: 12, s4: 16, s5: 20, s6: 32),
        radius: RadiusScale(control: 6, field: 6, card: 10),
        elevation: Elevation(cardShadowRadius: 0, cardShadowY: 0, cardShadowOpacity: 0),
        motion: Motion(reveal: .milliseconds(180), pulse: .milliseconds(1200)),
        charts: .standard)

    private enum PlatformRole {
        case surface, raised, separator
    }

    private static func platformColor(_ role: PlatformRole) -> Color {
        #if canImport(AppKit)
            switch role {
            case .surface: Color(nsColor: .textBackgroundColor)
            case .raised: Color(nsColor: .controlBackgroundColor)
            case .separator: Color(nsColor: .separatorColor)
            }
        #elseif canImport(UIKit)
            switch role {
            case .surface: Color(uiColor: .systemBackground)
            case .raised: Color(uiColor: .secondarySystemBackground)
            case .separator: Color(uiColor: .separator)
            }
        #else
            switch role {
            case .surface: Color.white
            case .raised: Color.white
            case .separator: Color.gray
            }
        #endif
    }
}
