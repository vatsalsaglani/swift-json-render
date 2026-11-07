import Testing

@testable import JSONRenderCore

/// Guards the parameterised parity suites against loading zero cases (a wrong path would
/// otherwise make them pass vacuously). Counts are from `Tests/ParityFixtures/README.md`.
@Suite("Fixture inventory")
struct FixtureInventoryTests {
    @Test(
        "Each jr-1a fixture folder loads every case",
        arguments: [("state", 71), ("expressions", 59), ("visibility", 76), ("actions", 27)])
    func caseCounts(_ folder: String, _ expected: Int) {
        #expect(ParityFixtures.cases(folder).count == expected)
    }

    @Test("Eight spec fixtures load")
    func specs() {
        #expect(JSONValueTests.specFixtureFiles().count == 8)
    }
}
