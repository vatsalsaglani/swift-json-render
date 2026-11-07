// Owner: jr-3 (wave 2); seeded by jr-1b.
public import SwiftUI

extension EnvironmentValues {
    /// The theme json-render views read. Default: `JSONRenderTheme.native`.
    ///
    /// Inside a `JSONRenderView` every element sets this to its effective theme (per-type
    /// theme, else this theme with the token overrides applied, adjusted for Increase
    /// Contrast), so a style or a replacement view reads one finished value.
    @Entry public var jsonRenderTheme: JSONRenderTheme = .native
    /// Whole themes for element types, set by `jsonRenderTheme(_:forTypes:)`.
    @Entry public var jsonRenderTypeThemes: [String: JSONRenderTheme] = [:]
    /// Single-token overrides, set by `jsonRenderTheme(_:_:)`.
    @Entry public var jsonRenderThemeTokens: JRThemeTokenOverrides = JRThemeTokenOverrides()
}

extension View {
    /// Sets the whole theme for this subtree.
    public func jsonRenderTheme(_ theme: JSONRenderTheme) -> some View {
        environment(\.jsonRenderTheme, theme)
    }

    /// Overrides one token for this subtree, for example
    /// `.jsonRenderTheme(\.radius.card, 6)`. Token overrides apply on top of the whole theme
    /// wherever it is set, so their order relative to `jsonRenderTheme(_:)` does not matter.
    public func jsonRenderTheme<V: Equatable & Sendable>(
        _ keyPath: any WritableKeyPath<JSONRenderTheme, V> & Sendable, _ value: V
    ) -> some View {
        transformEnvironment(\.jsonRenderThemeTokens) { overrides in
            overrides.set(keyPath, value)
        }
    }

    /// Uses `theme` for every element whose type is in `types` (and that element's
    /// subtree). It beats token overrides and the whole theme.
    public func jsonRenderTheme(_ theme: JSONRenderTheme, forTypes types: Set<String>)
        -> some View
    {
        transformEnvironment(\.jsonRenderTypeThemes) { themes in
            for type in types { themes[type] = theme }
        }
    }
}

/// An ordered list of single-token theme overrides. Equal when the same key paths hold
/// equal values, so re-applying a modifier with the same value does not invalidate views.
public struct JRThemeTokenOverrides: Sendable, Equatable {
    struct Entry: Sendable {
        let key: any Hashable & Sendable
        let value: any Equatable & Sendable
        let apply: @Sendable (inout JSONRenderTheme) -> Void
    }

    private(set) var entries: [Entry] = []

    public init() {}

    public var isEmpty: Bool { entries.isEmpty }

    /// Adds an override, replacing an earlier one for the same key path.
    public mutating func set<V: Equatable & Sendable>(
        _ keyPath: any WritableKeyPath<JSONRenderTheme, V> & Sendable, _ value: V
    ) {
        let entry = Entry(key: keyPath, value: value) { theme in theme[keyPath: keyPath] = value }
        if let index = entries.firstIndex(where: { AnyHashable($0.key) == AnyHashable(keyPath) }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    /// `theme` with every override applied, in order.
    public func applied(to theme: JSONRenderTheme) -> JSONRenderTheme {
        guard !entries.isEmpty else { return theme }
        var result = theme
        for entry in entries { entry.apply(&result) }
        return result
    }

    public static func == (lhs: JRThemeTokenOverrides, rhs: JRThemeTokenOverrides) -> Bool {
        guard lhs.entries.count == rhs.entries.count else { return false }
        for (left, right) in zip(lhs.entries, rhs.entries) {
            guard AnyHashable(left.key) == AnyHashable(right.key),
                isEqual(left.value, right.value)
            else { return false }
        }
        return true
    }

    private static func isEqual(_ lhs: any Equatable & Sendable, _ rhs: any Equatable & Sendable)
        -> Bool
    {
        func open<T: Equatable>(_ value: T) -> Bool { (rhs as? T) == value }
        return open(lhs)
    }
}

extension JSONRenderTheme {
    /// The theme an element of `type` uses: the per-type theme when there is one, else this
    /// theme with the token overrides applied; then adjusted for `contrast`.
    public func effective(
        forType type: String, typeThemes: [String: JSONRenderTheme],
        tokens: JRThemeTokenOverrides, contrast: ColorSchemeContrast
    ) -> JSONRenderTheme {
        (typeThemes[type] ?? tokens.applied(to: self)).adjusted(for: contrast)
    }

    /// Under Increase Contrast, muted text steps up to secondary text. (Hairlines get wider
    /// through `hairlineWidth(contrast:)`.)
    public func adjusted(for contrast: ColorSchemeContrast) -> JSONRenderTheme {
        guard contrast == .increased, color.textMuted != color.textSecondary else { return self }
        var copy = self
        copy.color.textMuted = copy.color.textSecondary
        return copy
    }

    /// 1 pt; 2 pt under Increase Contrast and for the `.highContrast` hairline.
    public func hairlineWidth(contrast: ColorSchemeContrast) -> CGFloat {
        contrast == .increased || color.hairline == JSONRenderTheme.highContrastHairline ? 2 : 1
    }
}
