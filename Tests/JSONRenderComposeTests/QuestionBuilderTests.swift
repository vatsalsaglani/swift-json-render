import JSONRenderCore
import Testing

@testable import JSONRenderCompose

@Suite("Question builders")
struct QuestionBuilderTests {
    private func firstCall(
        _ folder: String, catalog: Catalog, limits: ComposeLimits = .default
    ) async throws -> EvaluatorCall {
        let evaluator = RecordedEvaluator(try ComposeFixtures.responses(folder))
        let scenario = try ComposeFixtures.scenario(folder)
        let composer = try Composer(
            catalog: catalog, candidates: try ComposeFixtures.candidates(scenario.candidatesFolder),
            evaluator: evaluator, limits: limits)
        var iterator = composer.compose(
            prompt: scenario.prompt, context: ["team": "ops"], initialState: scenario.initialState
        ).makeAsyncIterator()
        _ = try await iterator.next()
        let calls = await evaluator.calls
        return try #require(calls.first)
    }

    @Test("Jev: root with one candidate plus unavailable, two predicates, one score")
    func jev() async throws {
        let call = try await firstCall("jev-preferences", catalog: MinimalCatalog.jev)
        #expect(call.names == ["root", "select_1", "select_2", "density"])
        guard case .choice(_, _, let choices)? = call.question("root") else {
            Issue.record("root is not a choice")
            return
        }
        #expect(choices.map(\.value) == ["preferences", "unavailable"])
        let kinds = call.questions.map(\.kind)
        #expect(kinds == ["choice", "predicate", "predicate", "score"])
        guard case .score(_, _, let levels)? = call.question("density") else {
            Issue.record("density is not a score")
            return
        }
        #expect(levels.map(\.label) == ["sparse", "normal", "dense"])
    }

    @Test("dashboard-24: groups, counts, and fewer than 100 questions over both rounds")
    func dashboard() async throws {
        let evaluator = RecordedEvaluator(try ComposeFixtures.responses("dashboard-24"))
        let scenario = try ComposeFixtures.scenario("dashboard-24")
        let composer = try Composer(
            catalog: MinimalCatalog.dashboard,
            candidates: try ComposeFixtures.candidates("dashboard-24"), evaluator: evaluator)
        _ = try await collect(composer.compose(prompt: scenario.prompt))
        let calls = await evaluator.calls
        try #require(calls.count == 2)
        let select = calls[0]
        // root + 19 groups + density.
        #expect(select.questions.count == 21)
        #expect(select.questions.filter { $0.kind == "predicate" }.count == 15)
        guard case .choice(_, _, let revenue)? = select.question("select_4") else {
            Issue.record("select_4 is not a choice")
            return
        }
        #expect(
            revenue.map(\.value) == [
                "omit", "use:revenue_stat", "use:revenue_chart", "use:revenue_table",
            ])
        guard case .choice(_, _, let counts)? = select.question("select_1") else {
            Issue.record("select_1 is not a choice")
            return
        }
        #expect(counts.map(\.value) == ["0", "1", "2", "3"])
        // Nine non-root elements: one parent and one order question each.
        #expect(calls[1].questions.count == 18)
        let total = calls.map(\.questions.count).reduce(0, +)
        #expect(total == 39)
        #expect(total < 100)
    }

    @Test("A repeated singleton asks counts 0...min(maxUses, maxElements)")
    func repeatedCounts() async throws {
        let stack = CompositionCandidate(
            id: "stack", description: "A stack", element: UIElement(type: "Stack"), maxUses: 9)
        let evaluator = ScriptedEvaluator(["root": "unavailable"])
        let composer = try Composer(
            catalog: MinimalCatalog.jev, candidates: [stack], evaluator: evaluator,
            limits: ComposeLimits(maxElements: 4))
        _ = try await collect(composer.compose(prompt: "stacks"))
        let call = try #require(await evaluator.calls.first)
        guard case .choice(_, _, let choices)? = call.question("select_0") else {
            Issue.record("select_0 is not a choice")
            return
        }
        #expect(choices.map(\.value) == ["0", "1", "2", "3", "4"])
    }

    @Test("Question names are unique in each request")
    func uniqueNames() async throws {
        let evaluator = RecordedEvaluator(try ComposeFixtures.responses("dashboard-24"))
        let composer = try Composer(
            catalog: MinimalCatalog.dashboard,
            candidates: try ComposeFixtures.candidates("dashboard-24"), evaluator: evaluator)
        _ = try await collect(composer.compose(prompt: "dashboard"))
        for call in await evaluator.calls {
            #expect(Set(call.names).count == call.names.count)
        }
    }

    @Test("The input never holds props, bindings, actions or the initial state")
    func inputIsBlind() async throws {
        let evaluator = RecordedEvaluator(try ComposeFixtures.responses("jev-preferences"))
        let composer = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: evaluator)
        _ = try await collect(
            composer.compose(
                prompt: "Preferences", context: ["locale": "en-GB"],
                initialState: ["name": "not-for-the-model", "privateToken": "secret-state"]))
        let calls = await evaluator.calls
        #expect(calls.count == 2)
        for call in calls {
            let text = call.input.text
            for forbidden in [
                "props", "\"on\"", "$bindState", "$state", "savePreferences", "initialState",
                "not-for-the-model", "secret-state", "Account preferences\"",
            ] {
                #expect(!text.contains(forbidden), "input holds \(forbidden)")
            }
            #expect(text.contains("en-GB"))
        }
        #expect(calls[0].input.text.contains("\"capabilities\""))
        #expect(calls[1].input.text.contains("\"selected_elements\""))
    }

    @Test("The input JSON is deterministic (sorted keys)")
    func deterministicInput() async throws {
        var texts: [String] = []
        for _ in 0..<2 {
            let evaluator = RecordedEvaluator(try ComposeFixtures.responses("jev-preferences"))
            let composer = try Composer(
                catalog: MinimalCatalog.jev,
                candidates: try ComposeFixtures.candidates("jev-preferences"), evaluator: evaluator)
            _ = try await collect(
                composer.compose(prompt: "p", context: ["b": 1, "a": 2, "c": ["z": 1, "y": 2]]))
            texts.append(try #require(await evaluator.calls.first).input.text)
        }
        #expect(texts[0] == texts[1])
        #expect(texts[0].hasPrefix("{\"capabilities\":"))
    }

    @Test("A slot name is encoded like encodeURIComponent")
    func slotEncoding() {
        #expect(QuestionBuilder.encodeURIComponent("side bar/x") == "side%20bar%2Fx")
        #expect(QuestionBuilder.encodeURIComponent("footer") == "footer")
    }

    @Test("More questions than the cap throw before any request")
    func tooManyQuestions() async throws {
        let candidates = (0..<5).map {
            CompositionCandidate(
                id: "panel\($0)", description: "Panel \($0)",
                element: UIElement(type: "Panel", props: ["title": "x"]))
        }
        let evaluator = ScriptedEvaluator([:])
        let composer = try Composer(
            catalog: MinimalCatalog.jev, candidates: candidates, evaluator: evaluator,
            limits: ComposeLimits(maxQuestionsPerRequest: 4))
        await #expect(throws: CompositionError.evaluator(.tooManyQuestions(7))) {
            _ = try await collect(composer.compose(prompt: "panels"))
        }
        #expect(await evaluator.calls.isEmpty)
    }
}
