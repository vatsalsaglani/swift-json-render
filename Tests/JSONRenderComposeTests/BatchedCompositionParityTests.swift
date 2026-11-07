import JSONRenderCompose
import JSONRenderCore
import Testing

/// Ports of the ten batched cases in upstream `experimental-compose.test.ts`
/// (`describe("batched composition")`), with the Decisions mapping: a non-repeated
/// singleton group is a predicate. Where upstream throws mid-stream, the Swift composer
/// ends with a stop reason and keeps the last valid preview (VPLAN 9.5, brief jr-6 §3).
@Suite("Batched composition parity")
struct BatchedCompositionParityTests {
    static let candidates: [CompositionCandidate] = [
        CompositionCandidate(
            id: "panel", description: "A telemetry panel", element: UIElement(type: "Panel"),
            maxUses: 5),
        CompositionCandidate(
            id: "temperature", description: "Temperature readout",
            element: UIElement(type: "Readout", props: ["value": ["$state": "/temperature"]]),
            root: false, resource: "reading"),
        CompositionCandidate(
            id: "alternate", description: "Alternate readout",
            element: UIElement(type: "Readout", props: ["value": 20]), root: false,
            resource: "reading"),
        CompositionCandidate(
            id: "inspect", description: "Inspect the reading",
            element: UIElement(
                type: "Trigger", props: ["label": "Inspect"],
                on: [
                    "activate": [
                        ActionBinding(
                            action: "inspect", params: ["reading": ["$state": "/temperature"]])
                    ]
                ]), root: false),
    ]

    static let initialState: JSONValue = ["temperature": 20, "privateToken": "not-for-the-model"]

    static let selections: [String: String] = [
        "root": "panel", "select_0": "1", "select_1": "use:temperature", "select_2": "yes",
        "density": "2",
    ]
    static let layout: [String: String] = [
        "parent_node_1": "node_0:default", "parent_node_2": "node_0:footer",
        "order_node_1": "1", "order_node_2": "1",
    ]

    static func batched(
        _ selections: [String: String] = [:], _ layout: [String: String] = [:]
    ) -> ScriptedEvaluator {
        ScriptedEvaluator(
            BatchedCompositionParityTests.selections.merging(selections) { $1 }
                .merging(BatchedCompositionParityTests.layout.merging(layout) { $1 }) { $1 })
    }

    static func composer(
        _ evaluator: any DecisionEvaluator, limits: ComposeLimits = .default
    ) throws -> Composer {
        try Composer(
            catalog: MinimalCatalog.telemetry, candidates: candidates, evaluator: evaluator,
            limits: limits)
    }

    static func run(_ evaluator: any DecisionEvaluator, limits: ComposeLimits = .default)
        async throws -> [ComposeEvent]
    {
        try await collect(
            composer(evaluator, limits: limits).compose(
                prompt: "Build a telemetry panel", initialState: initialState))
    }

    @Test("Renders content in the first of two evaluations and arranges named slots atomically")
    func firstPreviewThenLayout() async throws {
        let evaluator = Self.batched()
        let events = try await Self.run(evaluator)
        #expect(await evaluator.calls.count == 2)
        try #require(events.count == 3)
        let preview = try #require(events[0].spec)
        #expect(preview.elements["node_0"]?.children == ["node_1", "node_2"])
        #expect(preview.elements["node_1"]?.props == ["value": ["$state": "/temperature"]])
        let final = try #require(events[1].spec)
        #expect(final.elements["node_0"]?.children == ["node_1"])
        #expect(final.elements["node_0"]?.slots == ["footer": ["node_2"]])
        #expect(final.elements["node_2"]?.on == Self.candidates[3].element.on)
        #expect(events[2].stopReason == .finish)
        #expect(events[2].totalInputTokens == 20)
        #expect(events[2].steps.map(\.phase) == [.select, .layout])
        #expect(events[2].steps.map(\.index) == [0, 1])
    }

    @Test("Keeps resource variants mutually exclusive and caps repeated root instances")
    func resourcesAndRepeatedRoot() async throws {
        let evaluator = Self.batched(
            ["select_0": "2", "select_1": "use:alternate"],
            [
                "parent_node_1": "node_0:default", "order_node_1": "1",
                "parent_node_2": "node_1:default", "order_node_2": "1",
                "parent_node_3": "node_1:footer", "order_node_3": "1",
            ])
        let result = try #require(try await Self.run(evaluator).last?.spec)
        #expect(result.elements.values.filter { $0.type == "Panel" }.count == 2)
        #expect(result.elements["node_2"]?.props["value"] == 20)
        #expect(result.elements["node_1"]?.children == ["node_2"])
        #expect(result.elements["node_1"]?.slots == ["footer": ["node_3"]])
        let request = try #require(await evaluator.calls.first)
        guard case .choice(_, _, let root)? = request.question("root"),
            case .choice(_, _, let variants)? = request.question("select_1"),
            case .choice(_, _, let counts)? = request.question("select_0")
        else {
            Issue.record("Unexpected question kinds")
            return
        }
        #expect(!root.map(\.value).contains("temperature"))
        #expect(variants.map(\.value).contains("use:temperature"))
        #expect(variants.map(\.value).contains("use:alternate"))
        #expect(!counts.map(\.value).contains("6"))
    }

    @Test("Uses the evaluator's sibling order independently of candidate order")
    func siblingOrder() async throws {
        let events = try await Self.run(
            Self.batched(
                [:],
                ["parent_node_2": "node_0:default", "order_node_1": "2", "order_node_2": "1"]))
        let preview = try #require(events.first?.spec)
        let final = try #require(events.last?.spec)
        #expect(preview.elements["node_0"]?.children == ["node_1", "node_2"])
        #expect(final.elements["node_0"]?.children == ["node_2", "node_1"])
        #expect(final.elements["node_1"] == preview.elements["node_1"])
        #expect(final.elements["node_2"] == preview.elements["node_2"])
        #expect(final.state == preview.state)
    }

    @Test("Preserves the first valid preview when independently chosen parents form a cycle")
    func cycleKeepsPreview() async throws {
        let events = try await Self.run(
            Self.batched(
                ["select_0": "3"],
                [
                    "parent_node_1": "node_2:default", "parent_node_2": "node_1:default",
                    "parent_node_3": "node_0:default", "parent_node_4": "node_0:footer",
                    "order_node_1": "1", "order_node_2": "2", "order_node_3": "3",
                    "order_node_4": "4",
                ]))
        try #require(events.count == 2)
        #expect(events[0].isStep)
        #expect(events[0].spec?.elements["node_0"]?.children?.count == 4)
        #expect(events[1].stopReason == .limit)
        #expect(events[1].spec == events[0].spec)
        #expect(events[1].steps.last?.description.contains("layout rejected") == true)
    }

    @Test("Rejects a combined layout that exceeds the depth budget")
    func depthBudget() async throws {
        let events = try await Self.run(
            Self.batched(
                ["select_0": "3"],
                [
                    "parent_node_1": "node_0:default", "parent_node_2": "node_1:default",
                    "parent_node_3": "node_2:default", "parent_node_4": "node_0:footer",
                    "order_node_1": "1", "order_node_2": "2", "order_node_3": "3",
                    "order_node_4": "4",
                ]), limits: ComposeLimits(maxDepth: 3))
        #expect(events.last?.stopReason == .limit)
        #expect(events.last?.steps.last?.description.contains("maxDepth") == true)
        #expect(events.last?.spec == events.first?.spec)
    }

    @Test(
        "Reports element, depth and evaluation limits as partial output",
        arguments: [
            (ComposeLimits(maxElements: 2), 2), (ComposeLimits(maxDepth: 1), 1),
            (ComposeLimits(maxRounds: 1), 3),
        ])
    func limits(_ limits: ComposeLimits, _ maxElements: Int) async throws {
        let evaluator = Self.batched()
        let events = try await Self.run(evaluator, limits: limits)
        #expect(await evaluator.calls.count == 1)
        #expect(events.last?.stopReason == .limit)
        #expect((events.last?.spec?.elements.count ?? 99) <= maxElements)
    }

    @Test("Finishes single-element results in one call and keeps unavailable results empty")
    func singleAndUnavailable() async throws {
        let single = try await Self.run(Self.batched(["select_1": "omit", "select_2": "no"]))
        #expect(single.last?.stopReason == .finish)
        #expect(single.last?.steps.map(\.phase) == [.select])
        #expect(single.last?.spec?.elements.count == 1)
        let unavailable = try await Self.run(Self.batched(["root": "unavailable"]))
        #expect(unavailable.count == 1)
        #expect(unavailable.last?.stopReason == .unavailable)
        #expect(unavailable.last?.spec == nil)
    }

    @Test("Does not share state, and an injected value is never rendered")
    func noStateSharing() async throws {
        let evaluator = Self.batched()
        _ = try await Self.run(evaluator)
        for call in await evaluator.calls {
            #expect(!call.input.text.contains("not-for-the-model"))
            #expect(!call.input.text.contains("temperature\":20"))
        }
        let injected = try await Self.run(Self.batched(["root": "injection"]))
        let final = try #require(injected.last)
        #expect(final.spec?.elements["node_0"]?.type == "Panel")
        #expect(final.steps.first?.refused.contains("root") == true)
        #expect(final.steps.first?.fallbacks.contains("root") == true)
    }

    @Test("Missing, arbitrary and invalid answers never render")
    func invalidAnswers() async throws {
        // A value that was not offered, or a confidence that is not a number: a refusal.
        for override in [
            DecisionAnswer.choice(
                name: "root", choice: "injected", probabilities: [:], confidence: 1),
            .choice(name: "root", choice: "panel", probabilities: [:], confidence: .nan),
            .predicate(name: "root", probability: 1),
        ] {
            let evaluator = FunctionEvaluator { _, questions in
                scriptedResponse(
                    questions, Self.selections.merging(Self.layout) { $1 },
                    replacing: ["root": override])
            }
            let events = try await Self.run(evaluator)
            #expect(events.first?.steps.first?.refused == ["root"])
            #expect(events.last?.stopReason == .finish)
        }
        // No answers: wrong count, so nothing renders.
        let empty = try await Self.run(
            FunctionEvaluator { _, _ in DecisionResponse(answers: []) })
        #expect(empty.count == 1)
        #expect(empty.last?.stopReason == .unavailable)
        #expect(empty.last?.spec == nil)
        #expect(empty.last?.steps.first?.description.contains("invalidAnswer") == true)
        // Negative usage: refused as an invalid answer.
        let negative = try await Self.run(
            FunctionEvaluator { _, questions in
                scriptedResponse(
                    questions, Self.selections, usage: DecisionUsage(inputTokens: -1))
            })
        #expect(negative.last?.stopReason == .unavailable)
        // Unknown usage: the total is unknown.
        let unknown = try await Self.run(
            FunctionEvaluator { _, questions in
                scriptedResponse(questions, Self.selections.merging(Self.layout) { $1 }, usage: nil)
            })
        #expect(unknown.last?.stopReason == .finish)
        #expect(unknown.last?.totalInputTokens == nil)
    }

    @Test("Stops at consumer return without making a layout call")
    func consumerReturn() async throws {
        let evaluator = Self.batched()
        var iterator = try Self.composer(evaluator).compose(prompt: "p").makeAsyncIterator()
        let first = try await iterator.next()
        #expect(first?.isStep == true)
        #expect(await evaluator.calls.count == 1)
    }

    @Test("Cancelling the consuming task after the first step makes no layout call")
    func cancelAfterFirstStep() async throws {
        let evaluator = Self.batched()
        let stream = try Self.composer(evaluator).compose(prompt: "p")
        let consumer = Task {
            var iterator = stream.makeAsyncIterator()
            let first = try await iterator.next()
            withUnsafeCurrentTask { $0?.cancel() }
            let second = try? await iterator.next()
            return (first, second)
        }
        let (first, second) = try await consumer.value
        #expect(first?.isStep == true)
        #expect(second == nil)
        #expect(await evaluator.calls.count == 1)
    }

    @Test("Cancellation during a request ends the stream with CancellationError")
    func cancelDuringRequest() async throws {
        let evaluator = FunctionEvaluator { _, _ in
            withUnsafeCurrentTask { $0?.cancel() }
            throw CancellationError()
        }
        let stream = try Self.composer(evaluator).compose(prompt: "p")
        let consumer = Task { () -> [ComposeEvent] in
            var events: [ComposeEvent] = []
            do {
                for try await event in stream { events.append(event) }
            } catch is CancellationError {}
            return events
        }
        let events = try await consumer.value
        #expect(!events.contains { $0.isStep })
        #expect(await evaluator.calls.count == 1)
    }
}
