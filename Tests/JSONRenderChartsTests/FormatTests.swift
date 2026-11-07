import Foundation
import Testing

@testable import JSONRenderCharts

@Suite("Chart value formats")
struct FormatTests {
    let locale = Locale(identifier: "en_US")

    @Test("Compact, bytes, duration, percent and currency")
    func shortForms() {
        #expect(ChartValueFormat.compact.string(1_234, locale: locale) == "1.2k")
        #expect(ChartValueFormat.compact.string(3_400_000, locale: locale) == "3.4M")
        #expect(ChartValueFormat.compact.string(999, locale: locale) == "999")
        #expect(ChartValueFormat.bytes.string(3.4 * 1_048_576, locale: locale) == "3.4 MB")
        #expect(ChartValueFormat.bytes.string(512, locale: locale) == "512 B")
        #expect(ChartValueFormat.duration.string(41, locale: locale) == "41 s")
        #expect(ChartValueFormat.duration.string(125, locale: locale) == "2m 5s")
        #expect(ChartValueFormat.duration.string(0.25, locale: locale) == "250 ms")
        #expect(ChartValueFormat.percent.string(72, locale: locale) == "72 %")
        #expect(ChartValueFormat.currency("USD").string(3.6, locale: locale) == "$3.60")
        #expect(ChartValueFormat.number.string(1_296, locale: locale) == "1,296")
    }

    @Test("Units follow plain numbers only")
    func units() {
        #expect(ChartValueFormat.number.string(70, unit: "s", locale: locale) == "70 s")
        #expect(ChartValueFormat.compact.string(61_000, unit: "MB", locale: locale) == "61k MB")
        #expect(ChartValueFormat.percent.string(72, unit: "s", locale: locale) == "72 %")
        #expect(ChartValueFormat.number.axisString(70, locale: locale) == "70")
    }

    @Test("Parsing the format prop")
    func parsing() {
        #expect(ChartValueFormat(nil) == .number)
        #expect(ChartValueFormat("compact") == .compact)
        #expect(ChartValueFormat("currency:eur") == .currency("EUR"))
        #expect(ChartValueFormat("currency:") == nil)
        #expect(ChartValueFormat("currency:EURO") == nil)
        #expect(ChartValueFormat("money") == nil)
    }

    @Test("Non-finite values print a dash")
    func nonFinite() {
        #expect(ChartValueFormat.number.axisString(.nan) == "–")
    }
}
