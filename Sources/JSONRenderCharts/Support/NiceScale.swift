internal import Foundation

/// "Nice" axis numbers: 1, 2 and 5 times a power of ten.
public enum NiceScale {
    /// The smallest nice number ≥ `value` (for `value > 0`); `1` for zero, negatives and NaN.
    public static func ceil(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        let exponent = Foundation.floor(log10(value))
        let power = pow(10, exponent)
        let fraction = value / power
        for step in [1.0, 2, 5, 10] where fraction <= step * (1 + 1e-12) {
            return step * power
        }
        return 10 * power
    }

    /// The smallest "fine" nice number ≥ `value`: 1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6 or 8 times
    /// a power of ten (the static chart domain; less empty space than 1-2-5).
    public static func ceilFine(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        let power = pow(10, Foundation.floor(log10(value)))
        let fraction = value / power
        for step in [1.0, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10] where fraction <= step * (1 + 1e-12)
        {
            return step * power
        }
        return 10 * power
    }

    /// A nice domain that holds `range`. Zero is always inside when `includeZero` is set
    /// (bars start at zero). A flat range grows to a visible one. `fine` uses `ceilFine`
    /// for the ends; the streaming domain uses the coarser 1-2-5 steps.
    public static func domain(
        _ range: ClosedRange<Double>, includeZero: Bool = true, fine: Bool = true
    ) -> ClosedRange<Double> {
        func roundUp(_ value: Double) -> Double { fine ? ceilFine(value) : ceil(value) }
        guard includeZero else { return stepped(range) }
        let low = Swift.min(range.lowerBound, 0)
        let high = Swift.max(range.upperBound, 0)
        let upper = high > 0 ? roundUp(high) : (high == 0 ? 0 : -floorMagnitude(-high))
        let lower = low < 0 ? -roundUp(-low) : (low == 0 ? 0 : floorMagnitude(low))
        if upper <= lower { return lower...(lower + roundUp(Swift.max(abs(lower), 1))) }
        return lower...upper
    }

    /// A domain rounded out to multiples of a nice step (about four steps). For data that
    /// need not start at zero (scatter, sparkline).
    static func stepped(_ range: ClosedRange<Double>) -> ClosedRange<Double> {
        let span = range.upperBound - range.lowerBound
        let step = ceil(span > 0 ? span / 4 : Swift.max(abs(range.lowerBound), 1) / 4)
        let lower = Foundation.floor(range.lowerBound / step) * step
        var upper = Foundation.ceil(range.upperBound / step) * step
        if upper <= lower { upper = lower + step }
        return lower...upper
    }

    /// The largest nice number ≤ `value` (for `value > 0`).
    static func floorMagnitude(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 0 }
        let power = pow(10, Foundation.floor(log10(value)))
        let fraction = value / power
        for step in [5.0, 2, 1] where fraction >= step * (1 - 1e-12) {
            return step * power
        }
        return power
    }
}
