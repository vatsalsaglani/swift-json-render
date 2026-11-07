// Owner: jr-3 (wave 2). Skeleton: a static placeholder.
public import JSONRenderClient
public import JSONRenderSwiftUI
public import SwiftUI

/// What a skeleton style receives.
public struct JRSkeletonStyleConfiguration {
    public let shape: SkeletonShape
    /// A fixed width in points, or `nil`.
    public let width: CGFloat?
    /// A fixed height in points, or `nil`.
    public let height: CGFloat?
    /// `true` for a percentage width (or no width): stretch to the available width.
    public let fillsWidth: Bool
    public let rounded: Bool
    public let theme: JSONRenderTheme
}

/// Restyles every Skeleton in a subtree.
public protocol JRSkeletonStyle: Sendable {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: JRSkeletonStyleConfiguration) -> Body
}

/// The default skeleton: `JRSkeletonPlaceholder` (no shimmer, no pulse).
public struct DefaultJRSkeletonStyle: JRSkeletonStyle {
    public init() {}

    public func makeBody(configuration: JRSkeletonStyleConfiguration) -> some View {
        JRSkeletonPlaceholder(
            shape: configuration.shape, width: configuration.width, height: configuration.height,
            fillsWidth: configuration.fillsWidth, rounded: configuration.rounded)
    }
}

extension EnvironmentValues {
    /// The skeleton style. Default: `DefaultJRSkeletonStyle`.
    @Entry public var jrSkeletonStyle: any JRSkeletonStyle = DefaultJRSkeletonStyle()
}

extension View {
    /// Sets the style of every Skeleton in this subtree.
    public func jrSkeletonStyle(_ style: some JRSkeletonStyle) -> some View {
        environment(\.jrSkeletonStyle, style)
    }
}

/// `Skeleton`: upstream shadcn props plus `shape`. `width` / `height` take CSS-like strings:
/// `"24px"` or `"24"` is 24 pt, `"100%"` (any percentage) fills the width. The default is
/// the full width and (for a line) 20 pt high, as upstream.
@JRComponent("Skeleton", description: "Loading placeholder skeleton")
public struct JRSkeleton: View {
    @JRProp var width: String?
    @JRProp var height: String?
    @JRProp var rounded: Bool?
    @JRProp(
        description: "Placeholder shape: line (default), block, circle, card or tableBody.",
        oneOf: ["line", "block", "circle", "card", "tableBody"])
    var shape: String?

    @Environment(\.jrSkeletonStyle) private var style
    @Environment(\.jsonRenderTheme) private var theme

    public var body: some View {
        let width = SkeletonLength(width)
        let kind = shape.flatMap(SkeletonShape.init(rawValue:)) ?? .line
        let configuration = JRSkeletonStyleConfiguration(
            shape: kind, width: width.points,
            height: SkeletonLength(height).points ?? (kind == .line ? 20 : nil),
            fillsWidth: width.points == nil, rounded: rounded ?? false, theme: theme)
        JRStyleContent(style.makeBody(configuration: configuration))
    }
}

/// A CSS-like length: `"24px"`, `"24"`, `"1.5rem"` (16 pt per rem) or a percentage.
struct SkeletonLength: Equatable {
    /// Points, or `nil` for a percentage, an unknown unit or no value.
    let points: CGFloat?

    init(_ text: String?) {
        guard let raw = text?.trimmingCharacters(in: .whitespaces).lowercased(), !raw.isEmpty,
            !raw.hasSuffix("%")
        else {
            points = nil
            return
        }
        let (number, scale): (Substring, Double) =
            raw.hasSuffix("px")
            ? (raw.dropLast(2), 1) : raw.hasSuffix("rem") ? (raw.dropLast(3), 16) : (raw[...], 1)
        if let value = Double(number), value.isFinite, value >= 0 {
            points = CGFloat(min(value * scale, 4000))
        } else {
            points = nil
        }
    }
}
