import Foundation
import JSONRenderCompose
import JSONRenderCore
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

@Suite("OpenAI Decisions evaluator")
struct OpenAIDecisionsEvaluatorTests {
    static let testKey = "sk-test-DO-NOT-LOG-0123456789"

    /// The three question types the probe sent.
    static let probeQuestions: [DecisionQuestion] = [
        .choice(
            name: "root", instructions: "Which component should be the root?",
            choices: [
                DecisionChoice(value: "card", description: "A card"),
                DecisionChoice(value: "table", description: "A table"),
                DecisionChoice(value: "stat", description: "A stat"),
            ]),
        .predicate(name: "needs_chart", instructions: "Does this need a chart?"),
        .score(
            name: "density", instructions: "How dense?",
            levels: [
                DecisionLevel(label: "sparse", description: "Few"),
                DecisionLevel(label: "normal", description: "Some"),
                DecisionLevel(label: "dense", description: "Many"),
            ]),
    ]

    static func evaluator(
        recorder: TransportRecorder, status: Int = 200, body: Data,
        keyProvider: @escaping @Sendable () async throws -> String = { testKey },
        maxResponseBytes: Int = 1 << 20
    ) -> OpenAIDecisionsEvaluator {
        OpenAIDecisionsEvaluator(
            keyProvider: keyProvider, maxResponseBytes: maxResponseBytes,
            transport: { request in
                await recorder.record(request)
                return (
                    body,
                    httpResponse(
                        status, url: request.url ?? OpenAIDecisionsEvaluator.defaultBaseURL)
                )
            })
    }

    static func probeBody() throws -> Data {
        try ComposeFixtures.data("probe-2026-11-07.response.json")
    }

    @Test("The request is a POST to /v1/decisions with the key in Authorization only")
    func requestShape() async throws {
        let recorder = TransportRecorder()
        let evaluator = Self.evaluator(recorder: recorder, body: try Self.probeBody())
        _ = try await evaluator.decide(
            input: DecisionInput(text: "{\"user_request\":\"x\"}"), questions: Self.probeQuestions)
        let request = try #require(await recorder.requests.first)
        #expect(request.url?.absoluteString == "https://api.openai.com/v1/decisions")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.testKey)")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let body = try JSONDecoder().decode(JSONValue.self, from: try #require(request.httpBody))
        #expect(body["model"] == "gpt-6-luna")
        #expect(body["input"] == "{\"user_request\":\"x\"}")
        let questions = try #require(body["questions"]?.arrayValue)
        #expect(questions.map { $0["type"]?.stringValue } == ["choice", "predicate", "score"])
        #expect(questions[0]["choices"]?[0] == ["value": "card", "description": "A card"])
        #expect(questions[1]["choices"] == nil)
        #expect(questions[2]["levels"]?[2] == ["label": "dense", "description": "Many"])
        #expect(questions.map { $0["name"]?.stringValue } == ["root", "needs_chart", "density"])
        let text = String(decoding: try #require(request.httpBody), as: UTF8.self)
        #expect(!text.contains(Self.testKey))
    }

    @Test("The probe response decodes into three typed answers")
    func probeDecodes() async throws {
        let evaluator = Self.evaluator(recorder: TransportRecorder(), body: try Self.probeBody())
        let response = try await evaluator.decide(
            input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
        try #require(response.answers.count == 3)
        guard
            case .choice("root", "card", let choiceProbabilities, let choiceConfidence) =
                response.answers[0]
        else {
            Issue.record("root is not a choice")
            return
        }
        #expect(choiceProbabilities["card"] == 0.78)
        #expect(choiceConfidence == 0.67)
        #expect(response.answers[1] == .predicate(name: "needs_chart", probability: 0.0))
        guard
            case .score("density", let score, let scoreProbabilities, let scoreConfidence) =
                response.answers[2]
        else {
            Issue.record("density is not a score")
            return
        }
        #expect(score == 1.56)
        #expect(scoreConfidence == 0.34)
        #expect(scoreProbabilities[2] == 0.61)
        #expect(response.usage?.inputTokens == 429)
    }

    @Test("HTTP 429 is httpStatus(429) with no body")
    func httpStatus() async throws {
        let http = try ComposeFixtures.json("evaluator-429/http.json")
        let body = try JSONEncoder().encode(try #require(http["body"]))
        let evaluator = Self.evaluator(recorder: TransportRecorder(), status: 429, body: body)
        await #expect(throws: DecisionError.httpStatus(429)) {
            _ = try await evaluator.decide(
                input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
        }
    }

    @Test("An oversized body is malformedResponse")
    func oversized() async throws {
        let evaluator = Self.evaluator(
            recorder: TransportRecorder(), body: try Self.probeBody(), maxResponseBytes: 64)
        await #expect(
            throws: DecisionError.malformedResponse("The response is larger than the cap.")
        ) {
            _ = try await evaluator.decide(
                input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
        }
    }

    @Test("A refusal answer decodes as .refusal")
    func refusal() async throws {
        let body = Data(
            """
            {"answers":[{"type":"refusal","name":"needs_chart","reason":"policy"}],"usage":{"input_tokens":12}}
            """.utf8)
        let evaluator = Self.evaluator(recorder: TransportRecorder(), body: body)
        let response = try await evaluator.decide(
            input: DecisionInput(text: "{}"), questions: [Self.probeQuestions[1]])
        #expect(response.answers == [.refusal(name: "needs_chart")])
    }

    @Test("A wrong answer count or order is malformedResponse")
    func wrongCount() async throws {
        let evaluator = Self.evaluator(recorder: TransportRecorder(), body: try Self.probeBody())
        await #expect(throws: DecisionError.self) {
            _ = try await evaluator.decide(
                input: DecisionInput(text: "{}"), questions: Array(Self.probeQuestions.prefix(2)))
        }
        let reordered = [Self.probeQuestions[1], Self.probeQuestions[0], Self.probeQuestions[2]]
        do {
            _ = try await evaluator.decide(input: DecisionInput(text: "{}"), questions: reordered)
            Issue.record("A reordered response was accepted")
        } catch let error as DecisionError {
            guard case .malformedResponse = error else {
                Issue.record("Unexpected error \(error)")
                return
            }
        }
    }

    @Test("A body that is not a Decisions response is malformedResponse")
    func notDecisions() async throws {
        let evaluator = Self.evaluator(
            recorder: TransportRecorder(), body: Data("<html>gateway</html>".utf8))
        await #expect(
            throws: DecisionError.malformedResponse("The response is not a Decisions response.")
        ) {
            _ = try await evaluator.decide(
                input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
        }
    }

    @Test("A key provider that throws is keyUnavailable, and no request is made")
    func keyUnavailable() async throws {
        struct NoKey: Error {}
        let recorder = TransportRecorder()
        let providers: [@Sendable () async throws -> String] = [
            { @Sendable in throw NoKey() }, { @Sendable in "" },
        ]
        for provider in providers {
            let evaluator = Self.evaluator(
                recorder: recorder, body: try Self.probeBody(), keyProvider: provider)
            await #expect(throws: DecisionError.keyUnavailable) {
                _ = try await evaluator.decide(
                    input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
            }
        }
        #expect(await recorder.requests.isEmpty)
    }

    @Test("A non-https base URL is refused before the key is read")
    func insecureBaseURL() async throws {
        let recorder = TransportRecorder()
        let evaluator = OpenAIDecisionsEvaluator(
            keyProvider: {
                Issue.record("The key was read")
                return Self.testKey
            },
            baseURL: try #require(URL(string: "http://api.openai.com/v1")),
            transport: { request in
                await recorder.record(request)
                return (Data(), httpResponse(200, url: OpenAIDecisionsEvaluator.defaultBaseURL))
            })
        await #expect(throws: DecisionError.insecureBaseURL) {
            _ = try await evaluator.decide(
                input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
        }
        #expect(await recorder.requests.isEmpty)
    }

    @Test("More than 400 questions are refused before the key is read")
    func questionCap() async throws {
        let recorder = TransportRecorder()
        let evaluator = Self.evaluator(
            recorder: recorder, body: try Self.probeBody(),
            keyProvider: {
                Issue.record("The key was read")
                return Self.testKey
            })
        let questions = (0...400).map {
            DecisionQuestion.predicate(name: "q\($0)", instructions: "?")
        }
        await #expect(throws: DecisionError.tooManyQuestions(401)) {
            _ = try await evaluator.decide(input: DecisionInput(text: "{}"), questions: questions)
        }
        #expect(await recorder.requests.isEmpty)
    }

    @Test(
        "Transport errors map to codes",
        arguments: [URLError.Code.timedOut, .notConnectedToInternet])
    func transportErrors(_ code: URLError.Code) async throws {
        let evaluator = OpenAIDecisionsEvaluator(
            keyProvider: { Self.testKey }, transport: { _ in throw URLError(code) })
        await #expect(throws: code == .timedOut ? DecisionError.timeout : .transport) {
            _ = try await evaluator.decide(
                input: DecisionInput(text: "{}"), questions: Self.probeQuestions)
        }
    }

    @Test("Questions and answers round-trip through the wire Codable")
    func wireRoundTrip() throws {
        let data = try JSONEncoder().encode(Self.probeQuestions)
        #expect(
            try JSONDecoder().decode([DecisionQuestion].self, from: data) == Self.probeQuestions)
        let response = try ComposeFixtures.response("probe-2026-11-07.response.json")
        let again = try JSONDecoder().decode(
            DecisionResponse.self, from: try JSONEncoder().encode(response))
        #expect(again == response)
    }
}
