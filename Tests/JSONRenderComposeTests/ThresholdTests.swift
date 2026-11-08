import JSONRenderCore
import Testing

@testable import JSONRenderCompose

@Suite("Thresholds")
struct ThresholdTests {
    private func jevPreviewCount(nameProbability: Double) async throws -> Int {
        let evaluator = FunctionEvaluator { _, questions in
            scriptedResponse(
                questions, ["root": "preferences", "select_2": "no", "density": "1"],
                replacing: ["select_1": .predicate(name: "select_1", probability: nameProbability)])
        }
        let composer = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: evaluator)
        let events = try await collect(composer.compose(prompt: "p"))
        return try #require(events.first?.spec).elements.count
    }

    @Test("A predicate includes at 0.50 and leaves out at 0.49")
    func predicateThreshold() async throws {
        #expect(try await jevPreviewCount(nameProbability: 0.49) == 1)
        #expect(try await jevPreviewCount(nameProbability: 0.50) == 2)
    }

    @Test("A choice is accepted at confidence 0.35 and falls back at 0.34")
    func choiceThreshold() async throws {
        for (confidence, included) in [(0.34, false), (0.35, true)] {
            let evaluator = FunctionEvaluator { _, questions in
                scriptedResponse(
                    questions, BatchedCompositionParityTests.selections,
                    replacing: [
                        "select_1": .choice(
                            name: "select_1", choice: "use:temperature",
                            probabilities: ["use:temperature": confidence], confidence: confidence)
                    ])
            }
            let events = try await BatchedCompositionParityTests.run(evaluator)
            let preview = try #require(events.first?.spec)
            #expect(preview.elements.values.contains { $0.type == "Readout" } == included)
            let step = try #require(events.first?.steps.first)
            #expect(step.fallbacks.contains("select_1") == !included)
            #expect(step.refused.isEmpty)
        }
    }

    @Test(
        "Density scores round half down to a level",
        arguments: [
            (0.4, 0), (0.5, 0), (1.5, 1), (1.56, 2), (1.9, 2), (0.0, 0), (2.0, 2),
        ])
    func densityLevels(_ score: Double, _ level: Int) {
        #expect(AnswerReader.level(for: score, levels: 3) == level)
    }

    /// Every dashboard-24 question answered "yes": 21 elements before any cap.
    private func dashboardCount(density: Double, limits: ComposeLimits = .default) async throws
        -> (Int, ComposeStopReason?)
    {
        let evaluator = FunctionEvaluator { _, questions in
            DecisionResponse(
                answers: questions.map { question in
                    switch question {
                    case .predicate(let name, _): .predicate(name: name, probability: 1)
                    case .choice(let name, _, let choices):
                        .choice(
                            name: name,
                            choice: name == "root"
                                ? "dashboard"
                                : choices[0].value == "0"
                                    ? choices[choices.count - 1].value : choices[1].value,
                            probabilities: [:], confidence: 1)
                    case .score(let name, _, _):
                        .score(name: name, score: density, probabilities: [:], confidence: 0.9)
                    }
                })
        }
        let composer = try Composer(
            catalog: MinimalCatalog.dashboard,
            candidates: try ComposeFixtures.candidates("dashboard-24"),
            evaluator: evaluator, limits: limits)
        var iterator = composer.compose(prompt: "everything").makeAsyncIterator()
        let preview = try #require(try await iterator.next()?.spec)
        let next = try await iterator.next()
        return (preview.elements.count, next?.stopReason)
    }

    @Test("Density caps the element budget: 0.4 → 4, 1.5 → 12, 1.9 → all 21 (below 32)")
    func densityBudget() async throws {
        #expect(try await dashboardCount(density: 0.4) == (4, .limit))
        #expect(try await dashboardCount(density: 1.5) == (12, .limit))
        let dense = try await dashboardCount(density: 1.9)
        #expect(dense.0 == 21)
        #expect(dense.1 == nil)  // No stop yet: the layout round is next.
    }

    @Test("Density never raises the budget above maxElements")
    func densityCappedByMaxElements() async throws {
        #expect(
            try await dashboardCount(density: 1.9, limits: ComposeLimits(maxElements: 16)) == (
                16, .limit
            ))
    }

    @Test("Refusals are listed in step.refused and use their fallbacks")
    func refusals() async throws {
        let evaluator = FunctionEvaluator { _, questions in
            scriptedResponse(questions, ["select_1": "yes", "select_2": "yes"])
        }
        let composer = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: evaluator)
        let events = try await collect(composer.compose(prompt: "p"))
        let step = try #require(events.first?.steps.first)
        #expect(step.refused == ["root", "density"])
        #expect(step.fallbacks == ["root", "density"])
        #expect(events.first?.spec?.elements["node_0"]?.type == "Panel")
    }
}
