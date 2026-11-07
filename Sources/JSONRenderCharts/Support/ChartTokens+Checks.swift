internal import Foundation
public import JSONRenderSwiftUI
public import SwiftUI

/// A problem `ChartTokens.validated(against:in:)` finds.
public enum ChartTokenIssue: Sendable, Hashable {
    /// A categorical colour has less than 3:1 contrast against the card.
    case lowContrast(index: Int, ratio: Double)
    /// Two neighbouring categorical colours are too close (CIE76 ΔE < 20).
    case tooClose(index: Int, deltaE: Double)
    /// Two neighbours are too close on a protanopia-simulated copy (ΔE < 15).
    case tooCloseForProtanopia(index: Int, deltaE: Double)
}

/// The tokens failed the load-time check.
public struct ChartTokenError: Error, Sendable, Hashable {
    public let issues: [ChartTokenIssue]
}

extension ChartTokens {
    /// The minimum contrast of a categorical colour against the card.
    public static let minimumContrast = 3.0
    /// The minimum CIE76 ΔE between neighbouring categorical colours.
    public static let minimumDeltaE = 20.0
    /// The minimum ΔE between neighbours after a protanopia simulation (Viénot, Brettel and
    /// Mollon 1999, linear-RGB form).
    public static let minimumProtanopiaDeltaE = 15.0

    /// The categorical-palette problems against `surface`, with colours resolved in
    /// `environment` (set `colorScheme` to check light and dark).
    public func issues(against surface: Color, in environment: EnvironmentValues)
        -> [ChartTokenIssue]
    {
        let card = ChartColorMath.RGB(surface.resolve(in: environment))
        let colors = categorical.map { ChartColorMath.RGB($0.resolve(in: environment)) }
        var issues: [ChartTokenIssue] = []
        for (index, color) in colors.enumerated() {
            let ratio = ChartColorMath.contrast(color, card)
            if ratio < Self.minimumContrast {
                issues.append(.lowContrast(index: index, ratio: ratio))
            }
        }
        for index in colors.indices.dropLast() {
            let lhs = colors[index]
            let rhs = colors[index + 1]
            let distance = ChartColorMath.deltaE(lhs, rhs)
            if distance < Self.minimumDeltaE {
                issues.append(.tooClose(index: index, deltaE: distance))
            }
            let simulated = ChartColorMath.deltaE(lhs.protanopia, rhs.protanopia)
            if simulated < Self.minimumProtanopiaDeltaE {
                issues.append(.tooCloseForProtanopia(index: index, deltaE: simulated))
            }
        }
        return issues
    }

    /// The tokens, or an error listing every problem.
    public func validated(against surface: Color, in environment: EnvironmentValues)
        throws(ChartTokenError) -> ChartTokens
    {
        let found = issues(against: surface, in: environment)
        guard found.isEmpty else { throw ChartTokenError(issues: found) }
        return self
    }
}

/// Colour arithmetic on linear sRGB (`Color.Resolved` components are linear).
enum ChartColorMath {
    struct RGB: Hashable {
        var red: Double
        var green: Double
        var blue: Double

        init(red: Double, green: Double, blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        init(_ resolved: Color.Resolved) {
            red = Double(resolved.linearRed)
            green = Double(resolved.linearGreen)
            blue = Double(resolved.linearBlue)
        }

        /// WCAG relative luminance.
        var luminance: Double { 0.2126 * red + 0.7152 * green + 0.0722 * blue }

        /// The protanope view (Viénot 1999 matrix on linear RGB).
        var protanopia: RGB {
            let mixed = 0.11238 * red + 0.88762 * green
            return RGB(
                red: mixed, green: mixed,
                blue: max(0, min(1, 0.00401 * red - 0.00401 * green + blue)))
        }

        /// CIE L*a*b* (D65).
        var lab: (l: Double, a: Double, b: Double) {
            let x = (0.4124 * red + 0.3576 * green + 0.1805 * blue) / 0.95047
            let y = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            let z = (0.0193 * red + 0.1192 * green + 0.9505 * blue) / 1.08883
            func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16 / 116 }
            return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))
        }
    }

    static func contrast(_ lhs: RGB, _ rhs: RGB) -> Double {
        let high = max(lhs.luminance, rhs.luminance)
        let low = min(lhs.luminance, rhs.luminance)
        return (high + 0.05) / (low + 0.05)
    }

    static func deltaE(_ lhs: RGB, _ rhs: RGB) -> Double {
        let left = lhs.lab
        let right = rhs.lab
        let dl = left.l - right.l
        let da = left.a - right.a
        let db = left.b - right.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
