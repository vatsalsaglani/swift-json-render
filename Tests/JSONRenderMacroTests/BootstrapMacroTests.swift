import Testing

@testable import JSONRenderMacros

@Test("The macro test target builds and runs")
func macroBootstrap() {
    #expect(Bool(true))
}
