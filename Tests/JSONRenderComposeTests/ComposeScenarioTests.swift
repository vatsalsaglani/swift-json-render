import Foundation
import JSONRenderCompose
import JSONRenderCore
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Replays every `Tests/ParityFixtures/compose/<folder>/case.json` scenario.
@Suite("Compose scenarios")
struct ComposeScenarioTests {
    /// The evaluator for a scenario: recorded responses, or the real evaluator over a
    /// recorded HTTP transport.
    private func evaluator(_ scenario: ComposeCase) throws -> any DecisionEvaluator {
        guard let file = scenario.transportFile else {
            return RecordedEvaluator(try ComposeFixtures.responses(scenario.folder))
        }
        let http = try ComposeFixtures.json("\(scenario.folder)/\(file)")
        let status = Int(http["status"]?.numberValue ?? 500)
        let body = try JSONEncoder().encode(http["body"] ?? .null)
        return OpenAIDecisionsEvaluator(
            keyProvider: { "sk-test-DO-NOT-LOG-0123456789" },
            transport: { request in
                (
                    body,
                    httpResponse(
                        status, url: request.url ?? OpenAIDecisionsEvaluator.defaultBaseURL)
                )
            })
    }

    @Test("Each scenario ends as its case.json says", arguments: ComposeFixtures.scenarioFolders)
    func scenario(_ folder: String) async throws {
        let scenario = try ComposeFixtures.scenario(folder)
        let evaluator = try evaluator(scenario)
        let composer = try Composer(
            catalog: MinimalCatalog.named(scenario.catalogName),
            candidates: try ComposeFixtures.candidates(scenario.candidatesFolder),
            evaluator: evaluator)
        let events = try await collect(
            composer.compose(prompt: scenario.prompt, initialState: scenario.initialState))
        let final = try #require(events.last)
        #expect(final.stopReason?.rawValue == scenario.stopReason)
        #expect(final.steps.count == scenario.requests)
        #expect(final.spec?.elements.count == scenario.elements)
        if let recorded = evaluator as? RecordedEvaluator {
            #expect(await recorded.calls.count == scenario.requests)
        }
        // Every published spec is a valid tree.
        for event in events {
            guard let spec = event.spec else { continue }
            #expect(MinimalCatalog.named(scenario.catalogName).validate(spec).valid)
        }
        // A step is never published without a valid spec, and never after a failure.
        if final.stopReason == .unavailable {
            #expect(final.spec == nil)
            #expect(!events.contains { $0.isStep })
        }
        let steps = final.steps
        if !scenario.refused.isEmpty {
            #expect(steps.first?.refused == scenario.refused)
        }
        for name in scenario.fallbacks {
            #expect(steps.contains { $0.fallbacks.contains(name) })
        }
        if let children = scenario.rootChildren {
            #expect(final.spec?.elements["node_0"]?.children == children)
        }
    }

    @Test("jev-preferences composes to expected.spec.json")
    func jevExpected() async throws {
        let scenario = try ComposeFixtures.scenario("jev-preferences")
        let composer = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: RecordedEvaluator(try ComposeFixtures.responses("jev-preferences")))
        let events = try await collect(
            composer.compose(prompt: scenario.prompt, initialState: scenario.initialState))
        let expected = try ComposeFixtures.spec("jev-preferences/expected.spec.json")
        #expect(events.last?.spec == expected)
        #expect(events.count == 3)
        #expect(events.last?.totalInputTokens == 813)
    }

    @Test("dashboard-24 arranges stacks and the footer slot")
    func dashboardLayout() async throws {
        let scenario = try ComposeFixtures.scenario("dashboard-24")
        let composer = try Composer(
            catalog: MinimalCatalog.dashboard,
            candidates: try ComposeFixtures.candidates("dashboard-24"),
            evaluator: RecordedEvaluator(try ComposeFixtures.responses("dashboard-24")))
        let spec = try #require(
            try await collect(
                composer.compose(prompt: scenario.prompt, initialState: scenario.initialState)
            ).last?.spec)
        #expect(spec.elements["node_0"]?.slots == ["footer": ["node_9"]])
        #expect(spec.elements["node_1"]?.children == ["node_4"])
        #expect(spec.elements["node_2"]?.children == ["node_5", "node_6", "node_7"])
        #expect(spec.elements["node_4"]?.type == "Chart")
        #expect(spec.elements["node_5"]?.props["value"] == ["$state": "/latency/p95"])
        #expect(spec.state == ["title": "Operations"])
    }

    @Test("A 429 is reported as a code, never with the response body")
    func http429() async throws {
        let scenario = try ComposeFixtures.scenario("evaluator-429")
        let composer = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: try evaluator(scenario))
        let events = try await collect(composer.compose(prompt: scenario.prompt))
        let step = try #require(events.last?.steps.last)
        #expect(step.description.hasSuffix("evaluator: httpStatus(429)"))
        #expect(!step.description.contains("Rate limit"))
        #expect(step.inputTokens == nil)
        #expect(events.last?.totalInputTokens == 0)
    }
}

@Suite("Compose fixture inventory")
struct ComposeFixtureInventoryTests {
    @Test("Every scenario folder in the README loads", arguments: ComposeFixtures.scenarioFolders)
    func loads(_ folder: String) throws {
        let scenario = try ComposeFixtures.scenario(folder)
        #expect(!scenario.prompt.isEmpty)
        #expect(!(try ComposeFixtures.candidates(scenario.candidatesFolder)).isEmpty)
        if scenario.transportFile == nil {
            #expect(try ComposeFixtures.responses(folder).count >= 1)
        }
        let readme = String(decoding: try ComposeFixtures.data("README.md"), as: UTF8.self)
        #expect(readme.contains("`\(folder)`"))
    }

    @Test("Nine scenario folders and the probe response are present")
    func counts() throws {
        #expect(ComposeFixtures.scenarioFolders.count == 9)
        #expect(ComposeFixtures.exists("probe-2026-11-07.response.json"))
        #expect(try ComposeFixtures.candidates("dashboard-24").count == 24)
    }

    @Test("No fixture holds key material")
    func noKeys() throws {
        let enumerator = FileManager.default.enumerator(
            at: ComposeFixtures.root, includingPropertiesForKeys: nil)
        var files = 0
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension == "json" || url.pathExtension == "txt" else { continue }
            files += 1
            let text = String(decoding: try Data(contentsOf: url), as: UTF8.self)
            #expect(!text.contains("sk-"), "\(url.lastPathComponent)")
            #expect(!text.contains("Bearer"), "\(url.lastPathComponent)")
        }
        #expect(files > 20)
    }
}
