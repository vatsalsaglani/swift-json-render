// Owner: jr-3 (wave 2). WCAG contrast validation for themes.
internal import SwiftUI
internal import os

#if canImport(AppKit)
    internal import AppKit
#elseif canImport(UIKit)
    internal import UIKit
#endif

/// A theme failed the contrast check. Carries role names and ratios, never colour values
/// from a spec.
public struct ThemeContrastError: Error, Sendable, Hashable {
    /// One measured foreground/background pair.
    public struct Pair: Sendable, Hashable, CustomStringConvertible {
        /// The foreground role, for example `"textSecondary"`.
        public let foreground: String
        /// The background role, for example `"surface"`.
        public let background: String
        /// `"light"` or `"dark"`.
        public let appearance: String
        /// The measured WCAG 2 contrast ratio.
        public let ratio: Double
        /// The minimum ratio for this pair.
        public let required: Double

        public init(
            foreground: String, background: String, appearance: String, ratio: Double,
            required: Double
        ) {
            self.foreground = foreground
            self.background = background
            self.appearance = appearance
            self.ratio = ratio
            self.required = required
        }

        public var passes: Bool { ratio >= required }

        public var description: String {
            let measured = (ratio * 100).rounded() / 100
            return "\(foreground) on \(background) (\(appearance)): \(measured) < \(required)"
        }
    }

    /// The failing pairs.
    public let pairs: [Pair]

    public init(pairs: [Pair]) {
        self.pairs = pairs
    }
}

extension JSONRenderTheme {
    /// The pairs `validated()` checks and their minimum ratios.
    ///
    /// - Text and secondary text on both surfaces: 4.5:1 (WCAG AA for body text).
    /// - Muted text: 3.0:1. It is used for placeholders and hints next to a real label,
    ///   never as the only carrier of content (WCAG AA for large or incidental text).
    /// - Accent on the surface: 3.0:1 (non-text UI components, WCAG 1.4.11).
    /// - On-accent on the accent: 3.0:1, as VPLAN section 2.3 says. The macOS system accent
    ///   with white text measures about 4.0:1, so a 4.5:1 rule would reject the system
    ///   look. `.highContrast` picks black or white by contrast and passes 4.5:1.
    public static let contrastRules: [(foreground: String, background: String, minimum: Double)] =
        [
            ("text", "surface", 4.5), ("text", "surfaceRaised", 4.5),
            ("textSecondary", "surface", 4.5), ("textSecondary", "surfaceRaised", 4.5),
            ("textMuted", "surface", 3.0), ("accent", "surface", 3.0),
            ("onAccent", "accent", 3.0),
        ]

    /// Every rule pair measured in light and dark appearance.
    public func contrastReport() -> [ThemeContrastError.Pair] {
        var report: [ThemeContrastError.Pair] = []
        for appearance in ContrastMath.appearances {
            for rule in JSONRenderTheme.contrastRules {
                guard let foreground = color.role(rule.foreground),
                    let background = color.role(rule.background)
                else { continue }
                let ratio = ContrastMath.ratio(foreground, on: background, appearance: appearance)
                report.append(
                    ThemeContrastError.Pair(
                        foreground: rule.foreground, background: rule.background,
                        appearance: appearance, ratio: ratio, required: rule.minimum))
            }
        }
        return report
    }

    /// Returns `self` when every pair in `contrastRules` passes in light and dark appearance.
    /// Colours resolve to sRGB through the platform colour type; a translucent foreground is
    /// composited over its background first.
    public func validated() throws(ThemeContrastError) -> JSONRenderTheme {
        let failing = contrastReport().filter { !$0.passes }
        guard failing.isEmpty else { throw ThemeContrastError(pairs: failing) }
        return self
    }
}

extension ColorRoles {
    /// The colour for a role name (the property names of `ColorRoles`).
    func role(_ name: String) -> Color? {
        switch name {
        case "surface": surface
        case "surfaceRaised": surfaceRaised
        case "text": text
        case "textSecondary": textSecondary
        case "textMuted": textMuted
        case "hairline": hairline
        case "accent": accent
        case "onAccent": onAccent
        case "good": good
        case "warning": warning
        case "critical": critical
        case "info": info
        case "focus": focus
        default: nil
        }
    }
}

/// Checks each theme once per process and reports failures: an assertion in debug builds,
/// one log line (role names and ratios only) in release builds.
@MainActor
enum ThemeContrastAudit {
    private static var checked: [JSONRenderTheme] = []
    private static let logger = Logger(subsystem: "swift-json-render", category: "theme")

    static func check(_ theme: JSONRenderTheme) {
        guard !checked.contains(theme) else { return }
        if checked.count < 32 { checked.append(theme) }
        do {
            _ = try theme.validated()
        } catch {
            let summary = error.pairs.map(\.description).joined(separator: "; ")
            logger.warning("Theme contrast below minimum: \(summary, privacy: .public)")
            #if DEBUG
                if !isRunningTests { assertionFailure("Theme contrast below minimum: \(summary)") }
            #endif
        }
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
    }
}

/// WCAG 2 relative luminance and contrast.
enum ContrastMath {
    typealias RGBA = (red: Double, green: Double, blue: Double, alpha: Double)

    static let appearances = ["light", "dark"]

    static func ratio(_ foreground: Color, on background: Color, appearance: String) -> Double {
        let background = opaque(rgba(background, appearance: appearance), appearance: appearance)
        return ratio(foreground: rgba(foreground, appearance: appearance), background: background)
    }

    /// The ratio of a (possibly translucent) foreground over an opaque background.
    static func ratio(foreground: RGBA, background: RGBA) -> Double {
        let alpha = foreground.alpha
        let composite: RGBA = (
            foreground.red * alpha + background.red * (1 - alpha),
            foreground.green * alpha + background.green * (1 - alpha),
            foreground.blue * alpha + background.blue * (1 - alpha), 1
        )
        let lhs = luminance(composite)
        let rhs = luminance(background)
        return (max(lhs, rhs) + 0.05) / (min(lhs, rhs) + 0.05)
    }

    /// A translucent background composited over white (light) or black (dark).
    private static func opaque(_ color: RGBA, appearance: String) -> RGBA {
        guard color.alpha < 1 else { return color }
        let base = appearance == "dark" ? 0.0 : 1.0
        return (
            color.red * color.alpha + base * (1 - color.alpha),
            color.green * color.alpha + base * (1 - color.alpha),
            color.blue * color.alpha + base * (1 - color.alpha), 1
        )
    }

    static func luminance(_ color: RGBA) -> Double {
        func linear(_ value: Double) -> Double {
            value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722
            * linear(color.blue)
    }

    static func rgba(_ color: Color, appearance: String) -> RGBA {
        #if canImport(AppKit)
            let name: NSAppearance.Name = appearance == "dark" ? .darkAqua : .aqua
            var result: RGBA = (0, 0, 0, 1)
            NSAppearance(named: name)?.performAsCurrentDrawingAppearance {
                result = rgba(NSColor(color))
            }
            return result
        #elseif canImport(UIKit)
            let traits = UITraitCollection(
                userInterfaceStyle: appearance == "dark" ? .dark : .light)
            let resolved = UIColor(color).resolvedColor(with: traits)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            return (Double(red), Double(green), Double(blue), Double(alpha))
        #else
            return (0, 0, 0, 1)
        #endif
    }

    #if canImport(AppKit)
        /// Resolves in the current drawing appearance.
        static func rgba(_ color: NSColor) -> RGBA {
            guard let srgb = color.usingColorSpace(.sRGB) else { return (0, 0, 0, 1) }
            return (
                Double(srgb.redComponent), Double(srgb.greenComponent),
                Double(srgb.blueComponent), Double(srgb.alphaComponent)
            )
        }
    #endif
}
