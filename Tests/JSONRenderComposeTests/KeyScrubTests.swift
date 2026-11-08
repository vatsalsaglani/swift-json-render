import Foundation
import JSONRenderCompose
import JSONRenderCore
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// The test key must appear only in the `Authorization` header of the captured request:
/// never in an event, a step, an error, the evaluator's descriptions, or a request body.
@Suite("Key scrub")
struct KeyScrubTests {
    static let key = OpenAIDecisionsEvaluatorTests.testKey

    /// A transport that replays the jev fixtures, then fails with 429.
    static func evaluator(_ recorder: TransportRecorder) throws -> OpenAIDecisionsEvaluator {
        let bodies = [
            try ComposeFixtures.data("jev-preferences/select.response.json"),
            try ComposeFixtures.data("jev-preferences/layout.response.json"),
        ]
        return OpenAIDecisionsEvaluator(
            keyProvider: { key },
            transport: { request in
                await recorder.record(request)
                let index = await recorder.requests.count - 1
                let url = request.url ?? OpenAIDecisionsEvaluator.defaultBaseURL
                guard index < bodies.count else { return (Data(), httpResponse(429, url: url)) }
                return (bodies[index], httpResponse(200, url: url))
            })
    }

    private func texts(of events: [ComposeEvent]) -> [String] {
        events.flatMap { event in
            [String(describing: event), String(reflecting: event)]
                + event.steps.flatMap { [String(describing: $0), $0.description] }
        }
    }

    @Test("A full composition leaks the key nowhere but the Authorization header")
    func composition() async throws {
        let recorder = TransportRecorder()
        let evaluator = try Self.evaluator(recorder)
        let composer = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: evaluator)
        let events = try await collect(
            composer.compose(prompt: "Preferences", initialState: ["name": ""]))
        #expect(events.last?.stopReason == .finish)
        for text in texts(of: events) {
            #expect(!text.contains(Self.key))
        }
        for text in [
            String(describing: evaluator), String(reflecting: evaluator), evaluator.description,
            evaluator.debugDescription, String(describing: composer),
        ] {
            #expect(!text.contains(Self.key))
        }
        var dumped = ""
        dump(evaluator, to: &dumped)
        #expect(!dumped.contains(Self.key))

        let requests = await recorder.requests
        #expect(requests.count == 2)
        for request in requests {
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer \(Self.key)")
            let headers = request.allHTTPHeaderFields ?? [:]
            for (name, value) in headers where name != "Authorization" {
                #expect(!value.contains(Self.key))
            }
            let body = String(decoding: request.httpBody ?? Data(), as: UTF8.self)
            #expect(!body.contains(Self.key))
            #expect(request.url?.absoluteString.contains(Self.key) == false)
            #expect(!String(describing: request).contains(Self.key))
        }
    }

    @Test("Failures leak the key into no error and no step")
    func failures() async throws {
        let errors: [DecisionError] = [
            .httpStatus(429), .timeout, .transport, .malformedResponse("x"), .tooManyQuestions(401),
            .keyUnavailable,
        ]
        for error in errors {
            #expect(!String(describing: error).contains(Self.key))
            #expect(!String(reflecting: error).contains(Self.key))
            #expect(!error.localizedDescription.contains(Self.key))
        }
        // A third request fails with 429: the composer reports the code only.
        let recorder = TransportRecorder()
        _ = try await collect(
            Composer(
                catalog: MinimalCatalog.jev,
                candidates: try ComposeFixtures.candidates("jev-preferences"),
                evaluator: try Self.evaluator(recorder)
            ).compose(prompt: "first"))
        let failing = try Composer(
            catalog: MinimalCatalog.jev,
            candidates: try ComposeFixtures.candidates("jev-preferences"),
            evaluator: try Self.evaluator(recorder))
        let events = try await collect(failing.compose(prompt: "second"))
        #expect(events.last?.stopReason == .unavailable)
        for text in texts(of: events) {
            #expect(!text.contains(Self.key))
        }
        #expect(
            events.last?.steps.last?.description.hasSuffix("evaluator: httpStatus(429)") == true)
    }
}
