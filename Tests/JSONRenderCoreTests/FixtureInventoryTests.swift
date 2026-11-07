import Testing

@testable import JSONRenderCore

/// Guards the parameterised parity suites against loading zero cases (a wrong path would
/// otherwise make them pass vacuously). Counts are from `Tests/ParityFixtures/README.md`.
@Suite("Fixture inventory")
struct FixtureInventoryTests {
    @Test(
        "Each fixture folder loads every case",
        arguments: [
            ("state", 71), ("expressions", 59), ("visibility", 76), ("actions", 27),
            ("validation", 124),
        ])
    func caseCounts(_ folder: String, _ expected: Int) {
        #expect(ParityFixtures.cases(folder).count == expected)
    }

    @Test("Eight spec fixtures load")
    func specs() {
        #expect(JSONValueTests.specFixtureFiles().count == 8)
    }

    @Test("Forty-five validator cases load")
    func validator() {
        #expect(SpecValidatorParityTests.cases().count == 45)
    }
}
