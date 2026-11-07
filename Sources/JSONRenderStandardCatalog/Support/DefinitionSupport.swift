// Owner: jr-3 (wave 2). Shared helpers for standard component definitions and props.
internal import JSONRenderClient
internal import JSONRenderSwiftUI
internal import SwiftUI

extension ComponentDefinition {
    /// A copy with the schema of prop `name` replaced (field order and description kept).
    ///
    /// The `@JRComponent` macro maps `[JSONValue]` to `Array<unknown>`. Upstream prints
    /// object lists such as `Array<{ label: string, value: string }>`, so components with
    /// object-list props replace that one schema after registration.
    func replacingProp(_ name: String, with schema: PropSchema) -> ComponentDefinition {
        guard case .object(let fields) = props.kind else { return self }
        var copy = self
        copy.props.kind = .object(
            fields.map { field in
                guard field.name == name else { return field }
                var replacement = schema
                replacement.isOptional = field.schema.isOptional
                replacement.isNullable = field.schema.isNullable
                return PropSchema.Field(
                    name: field.name, schema: replacement, description: field.description)
            })
        return copy
    }
}

/// Object-list schemas the macro cannot express.
enum StandardSchemas {
    /// `Array<{ name: type, … }>` with every field required unless marked optional.
    static func objectList(_ fields: [(String, PropSchema)]) -> PropSchema {
        .array(.object(fields.map { PropSchema.Field(name: $0.0, schema: $0.1) }))
    }

    /// `Array<{ label: string, value: string }>`.
    static let labelValueList = objectList([("label", .string), ("value", .string)])
}

/// One `{ label, value }` entry of an object-list prop.
struct LabelValueItem: Hashable, Identifiable {
    let label: String
    let value: String
    var id: String { value }

    /// Decodes `[{ label, value }]`. An entry without a string `value` uses its label; an
    /// entry with neither is dropped. Duplicate values keep the first entry.
    static func list(_ values: [JSONValue]) -> [LabelValueItem] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let label = JRPropDecode.string(value["label"])
            guard let id = JRPropDecode.string(value["value"]) ?? label, seen.insert(id).inserted
            else { return nil }
            return LabelValueItem(label: label ?? id, value: id)
        }
    }
}

/// The gap names Stack and Grid share: none 0, sm 6, md 10, lg 16, xl 20.
enum StandardGap {
    static func points(_ name: String?, default fallback: CGFloat = 10) -> CGFloat {
        switch name {
        case "none": 0
        case "sm": 6
        case "md": 10
        case "lg": 16
        case "xl": 20
        default: fallback
        }
    }
}

/// A status meaning: an SF Symbol, a word for VoiceOver and a hue. Colour is never alone.
enum StandardStatus: String, CaseIterable {
    case neutral, info, good, warning, critical

    var symbol: String {
        switch self {
        case .neutral: "circle"
        case .info: "info.circle.fill"
        case .good: "checkmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .critical: "xmark.octagon.fill"
        }
    }

    var word: String {
        switch self {
        case .neutral: "Note"
        case .info: "Info"
        case .good: "Success"
        case .warning: "Warning"
        case .critical: "Error"
        }
    }

    func color(_ theme: JSONRenderTheme) -> Color {
        switch self {
        case .neutral: theme.color.textSecondary
        case .info: theme.color.info
        case .good: theme.color.good
        case .warning: theme.color.warning
        case .critical: theme.color.critical
        }
    }
}

extension View {
    /// A hairline border along a rounded rectangle: 1 pt, 2 pt under Increase Contrast.
    func standardHairline(_ theme: JSONRenderTheme, radius: CGFloat, isVisible: Bool = true)
        -> some View
    {
        modifier(HairlineBorder(theme: theme, radius: radius, isVisible: isVisible))
    }
}

private struct HairlineBorder: ViewModifier {
    let theme: JSONRenderTheme
    let radius: CGFloat
    let isVisible: Bool
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay {
            if isVisible {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        theme.color.hairline, lineWidth: theme.hairlineWidth(contrast: contrast))
            }
        }
    }
}
