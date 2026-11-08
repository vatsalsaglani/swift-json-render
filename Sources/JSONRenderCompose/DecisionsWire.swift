internal import Foundation
internal import JSONRenderCore

/// The `POST /v1/decisions` request body: `{ model, input, questions[] }`.
struct DecisionsWireRequest: Encodable {
    var model: String
    var input: String
    var questions: [DecisionQuestion]
}

enum DecisionsWire {
    /// Checks that a response answers `questions` one to one, by position and by name, and
    /// that the usage is sane. Returns a short reason, or `nil` when the shape is right.
    /// Fail closed: a mismatch is never re-assigned by name.
    static func shapeProblem(_ response: DecisionResponse, questions: [DecisionQuestion])
        -> (question: String, reason: String)?
    {
        guard response.answers.count == questions.count else {
            return (
                "", "expected \(questions.count) answers, got \(response.answers.count)"
            )
        }
        for (answer, question) in zip(response.answers, questions)
        where answer.name != question.name {
            return (question.name, "the answer at this position has another name")
        }
        if let usage = response.usage, usage.inputTokens < 0 {
            return ("", "usage is negative")
        }
        return nil
    }

    /// JSON text with sorted keys and unescaped slashes: one deterministic rendering.
    static func text(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
