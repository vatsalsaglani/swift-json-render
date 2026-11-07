/// The resource caps for one spec (VPLAN 6, 9.3).
///
/// A host can lower a cap but never raise it: every initialiser value is clamped to the
/// range `0...default`, and the properties are read-only after creation.
public struct SpecLimits: Sendable, Hashable {
    /// The largest accepted spec document, in bytes (256 KiB).
    public private(set) var maxBytes: Int
    /// The largest number of elements (2,000).
    public private(set) var maxElements: Int
    /// The deepest element nesting (64).
    public private(set) var maxDepth: Int
    /// The largest number of rows one `repeat` renders (500).
    public private(set) var maxRepeatRows: Int

    public static let defaultMaxBytes = 256 * 1024
    public static let defaultMaxElements = 2_000
    public static let defaultMaxDepth = 64
    public static let defaultMaxRepeatRows = 500

    public static let `default` = SpecLimits()

    public init(
        maxBytes: Int = SpecLimits.defaultMaxBytes,
        maxElements: Int = SpecLimits.defaultMaxElements,
        maxDepth: Int = SpecLimits.defaultMaxDepth,
        maxRepeatRows: Int = SpecLimits.defaultMaxRepeatRows
    ) {
        self.maxBytes = SpecLimits.clamp(maxBytes, SpecLimits.defaultMaxBytes)
        self.maxElements = SpecLimits.clamp(maxElements, SpecLimits.defaultMaxElements)
        self.maxDepth = SpecLimits.clamp(maxDepth, SpecLimits.defaultMaxDepth)
        self.maxRepeatRows = SpecLimits.clamp(maxRepeatRows, SpecLimits.defaultMaxRepeatRows)
    }

    private static func clamp(_ value: Int, _ ceiling: Int) -> Int {
        min(max(value, 0), ceiling)
    }
}
