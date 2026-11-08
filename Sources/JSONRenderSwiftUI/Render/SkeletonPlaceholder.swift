// Owner: jr-3 (wave 2). Static placeholders that hold the final layout.
public import SwiftUI

/// The placeholder shapes. `forType(_:)` picks the shape a streaming element of that type
/// will roughly occupy.
public enum SkeletonShape: String, Sendable, Hashable, CaseIterable {
    case line, block, circle, card, tableBody

    public static func forType(_ type: String) -> SkeletonShape {
        switch type {
        case "Card", "Dialog", "Drawer", "Accordion", "Tabs": .card
        case "Table": .tableBody
        case "Avatar": .circle
        case "Image", "Carousel", "Grid": .block
        default:
            type.hasSuffix("Chart") ? .block : .line
        }
    }
}

/// A static redacted shape: `surfaceRaised` with a light ink over it (black 6 % in light
/// appearance, white 10 % in dark) and a hairline. No shimmer, no spinner. VoiceOver reads
/// "Loading".
public struct JRSkeletonPlaceholder: View {
    let shape: SkeletonShape
    let width: CGFloat?
    let height: CGFloat?
    let fillsWidth: Bool
    let rounded: Bool
    @Environment(\.jsonRenderTheme) private var theme

    /// - `width` / `height`: a fixed size in points; `nil` uses the shape's default.
    /// - `fillsWidth`: stretch to the available width (a `"100%"` width).
    public init(
        shape: SkeletonShape, width: CGFloat? = nil, height: CGFloat? = nil,
        fillsWidth: Bool = false, rounded: Bool = false
    ) {
        self.shape = shape
        self.width = width
        self.height = height
        self.fillsWidth = fillsWidth
        self.rounded = rounded
    }

    public var body: some View {
        content
            .accessibilityElement()
            .accessibilityLabel(Text("Loading"))
    }

    @ViewBuilder
    private var content: some View {
        switch shape {
        case .line:
            bar(height: height ?? 12)
                .frame(width: width ?? (fillsWidth ? nil : 160))
                .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: .leading)
        case .block:
            filled(
                RoundedRectangle(
                    cornerRadius: rounded ? 999 : theme.radius.field, style: .continuous)
            )
            .overlay(outline(radius: rounded ? 999 : theme.radius.field))
            .frame(width: width, height: height ?? 96)
            .frame(maxWidth: width == nil ? .infinity : nil)
        case .circle:
            filled(Circle())
                .overlay(Circle().strokeBorder(theme.color.hairline, lineWidth: 1))
                .frame(width: width ?? height ?? 32, height: height ?? width ?? 32)
        case .card:
            VStack(alignment: .leading, spacing: theme.space.s3) {
                bar(height: 14).frame(width: 140)
                bar(height: 10).frame(maxWidth: .infinity)
                bar(height: 10).frame(width: 220)
            }
            .padding(theme.space.s3)
            .frame(maxWidth: width ?? .infinity, alignment: .leading)
            .frame(height: height)
            .overlay(outline(radius: theme.radius.card))
        case .tableBody:
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: theme.space.s4) {
                        bar(height: 10).frame(width: 120)
                        Spacer(minLength: 0)
                        bar(height: 10).frame(width: 48)
                    }
                    .padding(.vertical, theme.space.s2)
                    if row < 3 { Rectangle().fill(theme.color.hairline).frame(height: 1) }
                }
            }
            .frame(maxWidth: width ?? .infinity)
        }
    }

    /// The ink over the surface: `surfaceRaised` alone is too faint on a light window.
    static let ink = DynamicColor.ink(light: 0.06, dark: 0.10)

    private func filled(_ shape: some Shape) -> some View {
        shape.fill(theme.color.surfaceRaised).overlay(shape.fill(JRSkeletonPlaceholder.ink))
    }

    private func bar(height: CGFloat) -> some View {
        filled(RoundedRectangle(cornerRadius: rounded ? height / 2 : 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: rounded ? height / 2 : 4, style: .continuous)
                    .strokeBorder(theme.color.hairline, lineWidth: 1)
            )
            .frame(height: height)
    }

    private func outline(radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(theme.color.hairline, lineWidth: 1)
    }
}
