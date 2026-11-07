import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderCharts

@Suite("Chart tokens")
@MainActor
struct ChartTokensTests {
    func environment(_ scheme: ColorScheme) -> EnvironmentValues {
        var values = EnvironmentValues()
        values.colorScheme = scheme
        return values
    }

    @Test("The default tokens are complete")
    func present() {
        let tokens = ChartTokens.standard
        #expect(tokens.categorical.count == 8)
        #expect(tokens.sequential.count == 5)
        #expect(tokens.diverging.count == 5)
        #expect(tokens.lineWidth > 0 && tokens.pointSize > 0 && tokens.gaugeTrackWidth > 0)
        #expect(JSONRenderTheme.native.charts == tokens)
    }

    @Test(
        "Contrast ≥ 3:1 and neighbour ΔE checks pass on the native card",
        arguments: [ColorScheme.light, .dark])
    func contrast(scheme: ColorScheme) throws {
        let surface = JSONRenderTheme.native.color.surface
        let issues = ChartTokens.standard.issues(against: surface, in: environment(scheme))
        #expect(issues.isEmpty, "\(scheme): \(issues)")
        _ = try ChartTokens.standard.validated(against: surface, in: environment(scheme))
    }

    @Test("The adaptive palette resolves differently in light and dark")
    func adaptive() {
        let first = ChartTokens.standard.categorical[0]
        let light = first.resolve(in: environment(.light))
        let dark = first.resolve(in: environment(.dark))
        #expect(light != dark)
    }

    @Test("A low-contrast palette is reported")
    func lowContrast() {
        var tokens = ChartTokens.standard
        tokens.categorical = [Color(.sRGB, red: 0.94, green: 0.89, blue: 0.26), .black]
        let issues = tokens.issues(against: .white, in: environment(.light))
        #expect(issues.contains { if case .lowContrast(index: 0, _) = $0 { true } else { false } })
        #expect(throws: ChartTokenError.self) {
            try tokens.validated(against: .white, in: environment(.light))
        }
    }

    @Test("Close neighbours are reported")
    func tooClose() {
        var tokens = ChartTokens.standard
        tokens.categorical = [
            Color(.sRGB, red: 0, green: 0.45, blue: 0.70),
            Color(.sRGB, red: 0, green: 0.46, blue: 0.71),
        ]
        let issues = tokens.issues(against: .white, in: environment(.light))
        #expect(issues.contains { if case .tooClose = $0 { true } else { false } })
    }

    @Test("Colour math: white on black is 21:1; the same colour has ΔE 0")
    func math() {
        let white = ChartColorMath.RGB(red: 1, green: 1, blue: 1)
        let black = ChartColorMath.RGB(red: 0, green: 0, blue: 0)
        #expect(abs(ChartColorMath.contrast(white, black) - 21) < 1e-9)
        #expect(ChartColorMath.deltaE(white, white) == 0)
        #expect(abs(white.lab.l - 100) < 0.01)
    }
}
