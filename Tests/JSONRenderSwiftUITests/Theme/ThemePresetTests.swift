import JSONRenderSwiftUI
import SwiftUI
import Testing

@Suite struct ThemePresetTests {
    @Test(arguments: ["native", "highContrast"])
    func presetPassesValidation(_ name: String) throws {
        let theme: JSONRenderTheme = name == "native" ? .native : .highContrast
        #expect(throws: Never.self) { _ = try theme.validated() }
    }

    @Test func reportCoversEveryRuleInBothAppearances() {
        let report = JSONRenderTheme.native.contrastReport()
        #expect(report.count == JSONRenderTheme.contrastRules.count * 2)
        #expect(Set(report.map(\.appearance)) == ["light", "dark"])
    }

    @Test func highContrastOnAccentReachesBodyTextContrast() {
        let pairs = JSONRenderTheme.highContrast.contrastReport()
            .filter { $0.foreground == "onAccent" }
        #expect(pairs.count == 2)
        for pair in pairs { #expect(pair.ratio >= 4.5, "\(pair)") }
    }

    @Test func highContrastTextIsStrongerThanNative() {
        func ratio(_ theme: JSONRenderTheme, _ role: String) -> Double {
            theme.contrastReport().first {
                $0.foreground == role && $0.background == "surface" && $0.appearance == "light"
            }?.ratio ?? 0
        }
        #expect(ratio(.highContrast, "textSecondary") > ratio(.native, "textSecondary"))
        #expect(ratio(.highContrast, "textMuted") > ratio(.native, "textMuted"))
    }

    @Test func brokenThemeThrowsWithRoleNames() {
        var theme = JSONRenderTheme.native
        theme.color.textSecondary = Color(.sRGB, red: 0.8, green: 0.8, blue: 0.8)
        theme.color.onAccent = theme.color.accent
        do {
            _ = try theme.validated()
            Issue.record("expected a contrast error")
        } catch {
            let names = Set(error.pairs.map { "\($0.foreground)/\($0.background)" })
            #expect(names.contains("textSecondary/surface"))
            #expect(names.contains("onAccent/accent"))
            #expect(!names.contains("text/surface"))
            #expect(error.pairs.allSatisfy { !$0.passes })
        }
    }

    @Test func nativeTokenValues() {
        let theme = JSONRenderTheme.native
        #expect(theme.radius == RadiusScale(control: 7, field: 8, card: 12))
        #expect(theme.space == SpaceScale(s1: 4, s2: 8, s3: 12, s4: 16, s5: 20, s6: 32))
        #expect(theme.elevation.cardShadowRadius == 8)
        #expect(theme.elevation.cardShadowY == 2)
        #expect(theme.elevation.cardShadowOpacity == 0.10)
        #expect(theme.motion.reveal == .milliseconds(180))
        #expect(Motion.none.reveal == .zero && Motion.none.pulse == .zero)
        #expect(JSONRenderTheme.highContrast.charts == ChartTokens.defaults(role: .highContrast))
    }
}
