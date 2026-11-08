import Foundation
import JSONRenderCompose
import JSONRenderCore
import Testing

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// What an evaluator received for one request.
struct EvaluatorCall: Sendable {
    let input: DecisionInput
    let questions: [DecisionQuestion]

    var names: [String] { questions.map(\.name) }

    func question(_ name: String) -> DecisionQuestion? {
        questions.first { $0.name == name }
    }
}

/// Replays recorded responses, one per call, and records what it received. An extra call
/// is a test failure.
actor RecordedEvaluator: DecisionEvaluator {
    private let results: [Result<DecisionResponse, DecisionError>]
    private(set) var calls: [EvaluatorCall] = []

    init(_ responses: [DecisionResponse]) {
        results = responses.map { .success($0) }
    }

    init(results: [Result<DecisionResponse, DecisionError>]) {
        self.results = results
    }

    func decide(input: DecisionInput, questions: [DecisionQuestion]) async throws
        -> DecisionResponse
    {
        calls.append(EvaluatorCall(input: input, questions: questions))
        guard calls.count <= results.count else {
            Issue.record("The composer made an unexpected request \(calls.count).")
            throw DecisionError.transport
        }
        return try results[calls.count - 1].get()
    }
}

/// Answers every question from a name-to-value table, like upstream's `batched()` test
/// helper. Choice values are returned as given (also values that were not offered), with
/// confidence one. A predicate is "yes" for `"yes"` or a `use:` value. A score reads the
/// value as a number. A missing name is a refusal.
actor ScriptedEvaluator: DecisionEvaluator {
    private let answers: [String: String]
    private let confidence: Double
    private(set) var calls: [EvaluatorCall] = []

    init(_ answers: [String: String], confidence: Double = 1) {
        self.answers = answers
        self.confidence = confidence
    }

    func decide(input: DecisionInput, questions: [DecisionQuestion]) async throws
        -> DecisionResponse
    {
        calls.append(EvaluatorCall(input: input, questions: questions))
        return DecisionResponse(
            answers: questions.map { question in
                guard let value = answers[question.name] else {
                    return .refusal(name: question.name)
                }
                switch question {
                case .predicate(let name, _):
                    let yes = value == "yes" || value.hasPrefix("use:")
                    return .predicate(name: name, probability: yes ? 1 : 0)
                case .choice(let name, _, _):
                    return .choice(
                        name: name, choice: value, probabilities: [value: confidence],
                        confidence: confidence)
                case .score(let name, _, _):
                    return .score(
                        name: name, score: Double(value) ?? 1, probabilities: [:],
                        confidence: confidence)
                }
            }, usage: DecisionUsage(inputTokens: 10))
    }
}

/// Records the requests an `OpenAIDecisionsEvaluator` sends through its transport.
actor TransportRecorder {
    private(set) var requests: [URLRequest] = []

    func record(_ request: URLRequest) {
        requests.append(request)
    }
}

/// Collects a composition into its events.
func collect(_ stream: AsyncThrowingStream<ComposeEvent, any Error>) async throws
    -> [ComposeEvent]
{
    var events: [ComposeEvent] = []
    for try await event in stream { events.append(event) }
    return events
}

extension ComposeEvent {
    var spec: Spec? {
        switch self {
        case .step(let spec, _): spec
        case .complete(let spec, _, _, _, _): spec
        }
    }

    var stopReason: ComposeStopReason? {
        if case .complete(_, _, _, _, let reason) = self { return reason }
        return nil
    }

    var steps: [ComposeStep] {
        switch self {
        case .step(_, let step): [step]
        case .complete(_, let steps, _, _, _): steps
        }
    }

    var totalInputTokens: Int? {
        if case .complete(_, _, _, let tokens, _) = self { return tokens }
        return nil
    }

    var isStep: Bool {
        if case .step = self { return true }
        return false
    }
}

/// An HTTP response for an injected transport.
func httpResponse(_ status: Int, url: URL) -> HTTPURLResponse {
    guard
        let response = HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)
    else { preconditionFailure("A test response is valid.") }
    return response
}

/// Answers through a closure and counts calls. For exact numbers and malformed answers.
actor FunctionEvaluator: DecisionEvaluator {
    typealias Answer =
        @Sendable (_ call: Int, _ questions: [DecisionQuestion]) throws
        -> DecisionResponse
    private let answer: Answer
    private(set) var calls: [EvaluatorCall] = []

    init(_ answer: @escaping Answer) {
        self.answer = answer
    }

    func decide(input: DecisionInput, questions: [DecisionQuestion]) async throws
        -> DecisionResponse
    {
        calls.append(EvaluatorCall(input: input, questions: questions))
        return try answer(calls.count, questions)
    }
}

/// A scripted response with one answer replaced or the usage changed.
func scriptedResponse(
    _ questions: [DecisionQuestion], _ table: [String: String],
    replacing overrides: [String: DecisionAnswer] = [:],
    usage: DecisionUsage? = .init(inputTokens: 10)
) -> DecisionResponse {
    DecisionResponse(
        answers: questions.map { question in
            if let override = overrides[question.name] { return override }
            guard let value = table[question.name] else { return .refusal(name: question.name) }
            switch question {
            case .predicate(let name, _):
                let yes = value == "yes" || value.hasPrefix("use:")
                return .predicate(name: name, probability: yes ? 1 : 0)
            case .choice(let name, _, _):
                return .choice(name: name, choice: value, probabilities: [value: 1], confidence: 1)
            case .score(let name, _, _):
                return .score(
                    name: name, score: Double(value) ?? 1, probabilities: [:], confidence: 1)
            }
        }, usage: usage)
}
