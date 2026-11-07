/// The only network boundary of the composer. `OpenAIDecisionsEvaluator` is the real one;
/// tests replay recorded responses.
///
/// An evaluator must return one answer per question, in question order, with the question's
/// name. The composer checks this and treats a mismatch as an evaluator failure.
public protocol DecisionEvaluator: Sendable {
    func decide(input: DecisionInput, questions: [DecisionQuestion]) async throws
        -> DecisionResponse
}

/// Why an evaluator request failed. No case carries a response body, a request body or a
/// credential.
public enum DecisionError: Error, Sendable, Hashable {
    /// The HTTP status was not 2xx. The body is never carried.
    case httpStatus(Int)
    case timeout
    /// A transport failure (for example no connection). Only the category is kept.
    case transport
    /// The response did not have the expected shape. A short reason, no payload.
    case malformedResponse(String)
    /// More questions than the request cap allows. No request was made.
    case tooManyQuestions(Int)
    /// The key provider threw or returned an empty key. No request was made.
    case keyUnavailable
}
