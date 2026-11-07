// Owner: jr-3 (wave 2). Appearance-dependent colours for the presets.
internal import SwiftUI

#if canImport(AppKit)
    internal import AppKit
#elseif canImport(UIKit)
    internal import UIKit
#endif

/// Builds colours that follow light and dark appearance. Presets use it; components never
/// do (they read roles from the theme).
enum DynamicColor {
    /// A grey with `alpha` over the surface: black in light appearance, white in dark.
    static func ink(light lightAlpha: Double, dark darkAlpha: Double) -> Color {
        #if canImport(AppKit)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    isDark(appearance)
                        ? NSColor(white: 1, alpha: darkAlpha) : NSColor(white: 0, alpha: lightAlpha)
                })
        #elseif canImport(UIKit)
            Color(
                uiColor: UIColor { traits in
                    traits.userInterfaceStyle == .dark
                        ? UIColor(white: 1, alpha: darkAlpha) : UIColor(white: 0, alpha: lightAlpha)
                })
        #else
            Color.primary.opacity(lightAlpha)
        #endif
    }

    /// An opaque grey: `light` white level in light appearance, `dark` in dark.
    static func grey(light: Double, dark: Double) -> Color {
        #if canImport(AppKit)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    NSColor(white: isDark(appearance) ? dark : light, alpha: 1)
                })
        #elseif canImport(UIKit)
            Color(
                uiColor: UIColor { traits in
                    UIColor(white: traits.userInterfaceStyle == .dark ? dark : light, alpha: 1)
                })
        #else
            Color.gray
        #endif
    }

    /// Black or white, whichever has the higher contrast against the system accent colour
    /// in the current appearance.
    static func onAccent() -> Color {
        #if canImport(AppKit)
            Color(
                nsColor: NSColor(name: nil) { appearance in
                    var result = NSColor.white
                    appearance.performAsCurrentDrawingAppearance {
                        let accent = ContrastMath.rgba(NSColor.controlAccentColor)
                        let white = ContrastMath.ratio(
                            foreground: (1, 1, 1, 1), background: accent)
                        let black = ContrastMath.ratio(
                            foreground: (0, 0, 0, 1), background: accent)
                        result = black > white ? NSColor.black : NSColor.white
                    }
                    return result
                })
        #else
            Color.white
        #endif
    }

    #if canImport(AppKit)
        static func isDark(_ appearance: NSAppearance) -> Bool {
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        }
    #endif
}
