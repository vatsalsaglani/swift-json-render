import Testing

@testable import JSONRenderCore

/// `upstream/visibility/*.json`: `evaluateVisibility` and `splitRepeatVisibility`.
@Suite("Visibility parity (upstream/visibility)")
struct VisibilityParityTests {
    @Test("Replays the case", arguments: ParityFixtures.cases("visibility"))
    func replay(_ fixture: FixtureCase) throws {
        let condition = fixture.value("condition").map(VisibilityCondition.init(json:))
        switch fixture.kind {
        case "evaluate":
            let context = VisibilityContext(
                state: fixture.value("state") ?? [:],
                repeatItem: fixture.value("repeatItem"),
                repeatIndex: fixture.value("repeatIndex")?.numberValue.map { Int($0) })
            #expect(
                VisibilityEvaluator.evaluate(condition, in: context)
                    == fixture.value("expected")?.boolValue)
        case "split":
            let expected = fixture.raw("expected")
            let split = VisibilityCondition.splitForRepeat(condition)
            #expect(
                split.container?.jsonValue
                    == expected?["container"].flatMap(ParityFixtures.resolvingMarkers))
            #expect(
                split.itemFilter?.jsonValue
                    == expected?["itemFilter"].flatMap(ParityFixtures.resolvingMarkers))
        default:
            Issue.record("Unknown kind \(fixture.kind ?? "nil")")
        }
    }
}

@Suite("Visibility decoding")
struct VisibilityDecodeTests {
    @Test("Two operators: upstream precedence keeps the first, with a warning")
    func precedence() {
        let (condition, warnings) = VisibilityCondition.parse([
            "$state": "/n", "lt": 3, "gt": 1, "neq": 2,
        ])
        guard case .single(let single) = condition else {
            Issue.record("Not a single condition")
            return
        }
        #expect(single.comparison == .neq(2))
        #expect(warnings == [.extraOperators(kept: "neq", ignored: ["gt", "lt"])])
        // neq 2 wins: 5 != 2 is true although lt 3 would be false.
        #expect(VisibilityEvaluator.evaluate(condition, in: VisibilityContext(state: ["n": 5])))
        // The extra keys survive encoding.
        #expect(condition.jsonValue == ["$state": "/n", "lt": 3, "gt": 1, "neq": 2])
    }

    @Test("eq null is a comparison with null, not a missing operator")
    func eqNull() {
        let condition = VisibilityCondition(json: ["$state": "/missing", "eq": .null])
        #expect(!VisibilityEvaluator.evaluate(condition, in: VisibilityContext(state: [:])))
        #expect(
            VisibilityEvaluator.evaluate(
                condition, in: VisibilityContext(state: ["missing": .null])))
    }

    @Test("Subject precedence: $index, then $item, then $state")
    func subjectPrecedence() {
        guard case .single(let mixed) = VisibilityCondition(json: ["$state": "/a", "$item": "b"])
        else {
            Issue.record("Not single")
            return
        }
        #expect(mixed.subject == .item("b"))
        guard case .single(let index) = VisibilityCondition(json: ["$item": "b", "$index": true])
        else {
            Issue.record("Not single")
            return
        }
        #expect(index.subject == .index)
    }

    @Test("Shapes with no condition are invalid and hidden")
    func invalidShapes() {
        for raw: JSONValue in [.null, "x", 3, [:], ["when": "/a"], ["$and": "x"], ["$state": 5]] {
            let condition = VisibilityCondition(json: raw)
            #expect(condition == .invalid(raw), "\(raw)")
            #expect(
                !VisibilityEvaluator.evaluate(condition, in: VisibilityContext(state: ["a": true])))
            #expect(condition.jsonValue == raw)
        }
    }

    @Test("Numeric operands: $state reads state; other types never compare")
    func operands() {
        let state: JSONValue = ["n": 5, "limit": 7]
        #expect(
            VisibilityEvaluator.evaluate(
                VisibilityCondition(json: ["$state": "/n", "lt": ["$state": "/limit"]]),
                in: VisibilityContext(state: state)))
        #expect(
            !VisibilityEvaluator.evaluate(
                VisibilityCondition(json: ["$state": "/n", "lt": "9"]),
                in: VisibilityContext(state: state)))
        #expect(
            VisibilityEvaluator.evaluate(
                VisibilityCondition(json: ["$state": "/n", "lt": "9", "not": true]),
                in: VisibilityContext(state: state)))
        #expect(
            !VisibilityEvaluator.evaluate(
                VisibilityCondition(json: ["$state": "/n", "not": false]),
                in: VisibilityContext(state: [:])))
    }

    @Test("Programmatic conditions encode their fields")
    func programmatic() {
        let single = SingleCondition(
            subject: .state("/a/b"), comparison: .gte(.state("/c")), not: true)
        #expect(single.source == ["$state": "/a/b", "gte": ["$state": "/c"], "not": true])
        #expect(
            VisibilityCondition.or([.single(single), .always(false)]).jsonValue == [
                "$or": [["$state": "/a/b", "gte": ["$state": "/c"], "not": true], false]
            ])
    }

    @Test("usesItemScope looks through every form")
    func itemScope() {
        #expect(!VisibilityCondition(json: ["$state": "/a"]).usesItemScope)
        #expect(
            VisibilityCondition(json: ["$or": [["$state": "/a"], [["$index": true]]]]).usesItemScope
        )
        #expect(VisibilityCondition(json: ["$and": [["$item": "x"]]]).usesItemScope)
        #expect(!VisibilityCondition.always(true).usesItemScope)
    }
}
