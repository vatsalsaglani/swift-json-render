import JSONRenderSwiftUI
import SwiftUI
import Testing

@Suite struct ThemeEnvironmentTests {
    @Test func tokenOverrideAppliesOnTopOfTheWholeTheme() {
        var tokens = JRThemeTokenOverrides()
        tokens.set(\.radius.card, 4)
        let effective = JSONRenderTheme.highContrast.effective(
            forType: "Card", typeThemes: [:], tokens: tokens, contrast: .standard)
        #expect(effective.radius.card == 4)
        #expect(effective.color.hairline == JSONRenderTheme.highContrast.color.hairline)
    }

    @Test func perTypeThemeBeatsTokenOverrides() {
        var tokens = JRThemeTokenOverrides()
        tokens.set(\.radius.card, 4)
        let typeThemes = ["Alert": JSONRenderTheme.highContrast]
        let alert = JSONRenderTheme.native.effective(
            forType: "Alert", typeThemes: typeThemes, tokens: tokens, contrast: .standard)
        let card = JSONRenderTheme.native.effective(
            forType: "Card", typeThemes: typeThemes, tokens: tokens, contrast: .standard)
        #expect(alert == JSONRenderTheme.highContrast)
        #expect(card.radius.card == 4)
        #expect(card.color.hairline == JSONRenderTheme.native.color.hairline)
    }

    @Test func laterOverrideOfTheSameTokenReplacesTheEarlierOne() {
        var tokens = JRThemeTokenOverrides()
        tokens.set(\.radius.card, 4)
        tokens.set(\.space.s3, 14)
        tokens.set(\.radius.card, 6)
        let theme = tokens.applied(to: .native)
        #expect(theme.radius.card == 6)
        #expect(theme.space.s3 == 14)
    }

    @Test func overridesCompareByKeyPathAndValue() {
        var lhs = JRThemeTokenOverrides()
        lhs.set(\.radius.card, 4)
        var rhs = JRThemeTokenOverrides()
        rhs.set(\.radius.card, 4)
        #expect(lhs == rhs)
        rhs.set(\.radius.card, 5)
        #expect(lhs != rhs)
        #expect(JRThemeTokenOverrides().isEmpty)
    }

    @Test func increaseContrastRaisesMutedTextAndHairlines() {
        let theme = JSONRenderTheme.native
        let adjusted = theme.adjusted(for: .increased)
        #expect(adjusted.color.textMuted == theme.color.textSecondary)
        #expect(theme.adjusted(for: .standard) == theme)
        #expect(theme.hairlineWidth(contrast: .standard) == 1)
        #expect(theme.hairlineWidth(contrast: .increased) == 2)
        #expect(JSONRenderTheme.highContrast.hairlineWidth(contrast: .standard) == 2)
    }
}
