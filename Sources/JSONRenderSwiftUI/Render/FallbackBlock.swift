// Owner: jr-3 (wave 2). The calm fallback for an element that cannot be drawn.
public import SwiftUI

/// A hairline box with a symbol and one line of text: the type name or a reason. It never
/// shows prop values.
public struct JRFallbackBlock: View {
    let reason: String
    let symbol: String
    @Environment(\.jsonRenderTheme) private var theme
    @Environment(\.colorSchemeContrast) private var contrast

    public init(reason: String, symbol: String = "square.dashed") {
        self.reason = reason
        self.symbol = symbol
    }

    public var body: some View {
        Label(reason, systemImage: symbol)
            .font(theme.type.footnote)
            .foregroundStyle(theme.color.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, theme.space.s3)
            .padding(.vertical, theme.space.s2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.field, style: .continuous)
                    .strokeBorder(
                        theme.color.hairline,
                        style: StrokeStyle(
                            lineWidth: theme.hairlineWidth(contrast: contrast), dash: [4, 3]))
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Cannot show \(reason)"))
    }
}
