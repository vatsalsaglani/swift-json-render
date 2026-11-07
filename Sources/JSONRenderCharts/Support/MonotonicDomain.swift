/// A y-domain that only grows while a chart streams, so the chart does not jump.
///
/// `include(_:)` widens the domain to a nice range that holds the new data and never
/// shrinks it. `settle(_:)` replaces it with the final nice domain (call it once when the
/// stream ends; the view animates that one step, or not at all under Reduce Motion).
public struct MonotonicDomain: Sendable, Hashable {
    /// The current domain, or `nil` before any data.
    public private(set) var current: ClosedRange<Double>?

    public init() {}

    /// Widens the domain so it holds `range`, rounded out to nice numbers. Never shrinks.
    @discardableResult
    public mutating func include(
        _ range: ClosedRange<Double>, includeZero: Bool = true
    ) -> ClosedRange<Double> {
        var wanted = range
        if let current {
            wanted =
                Swift.min(
                    current.lowerBound, range.lowerBound)...Swift.max(
                    current.upperBound, range.upperBound)
        }
        let nice = NiceScale.domain(wanted, includeZero: includeZero, fine: false)
        let next: ClosedRange<Double>
        if let current {
            next =
                Swift.min(
                    current.lowerBound, nice.lowerBound)...Swift.max(
                    current.upperBound, nice.upperBound)
        } else {
            next = nice
        }
        current = next
        return next
    }

    /// Sets the final nice domain for `range` (it may be smaller than the streaming one).
    @discardableResult
    public mutating func settle(
        _ range: ClosedRange<Double>, includeZero: Bool = true
    ) -> ClosedRange<Double> {
        let nice = NiceScale.domain(range, includeZero: includeZero)
        current = nice
        return nice
    }

    /// Forgets the domain.
    public mutating func reset() { current = nil }
}
