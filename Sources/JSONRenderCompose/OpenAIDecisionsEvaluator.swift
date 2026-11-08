public import Foundation

#if canImport(FoundationNetworking)
    public import FoundationNetworking
#endif

/// A `DecisionEvaluator` that calls the OpenAI Decisions API (`POST {baseURL}/decisions`).
///
/// The key comes from `keyProvider` once per request and goes only into the
/// `Authorization` header of that request. The evaluator does not store it, log it, or put
/// it in an error or a description. Request and response bodies are never logged.
///
/// Tests and Linux hosts inject `transport`; the default transport is an ephemeral
/// `URLSession` per request with no cookies and no cache.
public struct OpenAIDecisionsEvaluator: DecisionEvaluator, CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable
{
    /// Sends one request and returns the body and the HTTP response.
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    public let baseURL: URL
    public let model: String
    public let timeout: Duration
    public let maxResponseBytes: Int
    private let keyProvider: @Sendable () async throws -> String
    private let transport: Transport?

    public init(
        keyProvider: @escaping @Sendable () async throws -> String,
        baseURL: URL = OpenAIDecisionsEvaluator.defaultBaseURL,
        model: String = "gpt-6-luna",
        timeout: Duration = .seconds(10),
        maxResponseBytes: Int = 1 << 20,
        transport: Transport? = nil
    ) {
        self.keyProvider = keyProvider
        self.baseURL = baseURL
        self.model = model
        self.timeout = timeout
        self.maxResponseBytes = maxResponseBytes
        self.transport = transport
    }

    /// `https://api.openai.com/v1`.
    public static let defaultBaseURL: URL = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.openai.com"
        components.path = "/v1"
        guard let url = components.url else { preconditionFailure("A constant URL is valid.") }
        return url
    }()

    public var description: String {
        "OpenAIDecisionsEvaluator(model: \(model), baseURL: \(baseURL.absoluteString))"
    }

    public var debugDescription: String { description }

    public var customMirror: Mirror {
        Mirror(self, children: ["model": model, "baseURL": baseURL.absoluteString])
    }

    public func decide(input: DecisionInput, questions: [DecisionQuestion]) async throws
        -> DecisionResponse
    {
        guard questions.count <= ComposeLimits.apiQuestionCap else {
            throw DecisionError.tooManyQuestions(questions.count)
        }
        let body: Data
        do {
            body = try JSONEncoder().encode(
                DecisionsWireRequest(model: model, input: input.text, questions: questions))
        } catch {
            throw DecisionError.malformedResponse("The request could not be encoded.")
        }
        try Task.checkCancellation()
        let request = try await makeRequest(body: body)
        let (data, response) = try await send(request)
        guard (200..<300).contains(response.statusCode) else {
            throw DecisionError.httpStatus(response.statusCode)
        }
        guard data.count <= maxResponseBytes else {
            throw DecisionError.malformedResponse("The response is larger than the cap.")
        }
        let decoded: DecisionResponse
        do {
            decoded = try JSONDecoder().decode(DecisionResponse.self, from: data)
        } catch {
            throw DecisionError.malformedResponse("The response is not a Decisions response.")
        }
        if let problem = DecisionsWire.shapeProblem(decoded, questions: questions) {
            throw DecisionError.malformedResponse(problem.reason)
        }
        return decoded
    }

    /// The only place a `URLRequest` is built. The key lives in a local and in the header.
    private func makeRequest(body: Data) async throws -> URLRequest {
        // The key never travels in clear text: refuse before the key provider runs.
        guard baseURL.scheme?.lowercased() == "https" else { throw DecisionError.insecureBaseURL }
        let key: String
        do {
            key = try await keyProvider()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw DecisionError.keyUnavailable
        }
        guard !key.isEmpty else { throw DecisionError.keyUnavailable }
        var request = URLRequest(url: baseURL.appendingPathComponent("decisions"))
        request.httpMethod = "POST"
        request.timeoutInterval = Self.seconds(timeout)
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    private func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            if let transport { return try await transport(request) }
            return try await Self.sessionTransport(request, timeout: timeout)
        } catch let error as DecisionError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError {
            switch error.code {
            case .timedOut: throw DecisionError.timeout
            case .cancelled: throw CancellationError()
            default: throw DecisionError.transport
            }
        } catch {
            throw DecisionError.transport
        }
    }

    /// The default transport: one ephemeral session per request, no cookies, no cache.
    /// `URLSession.data(for:)` cancels the request when the calling task is cancelled.
    private static func sessionTransport(_ request: URLRequest, timeout: Duration) async throws
        -> (Data, HTTPURLResponse)
    {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = seconds(timeout)
        configuration.timeoutIntervalForResource = seconds(timeout)
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DecisionError.malformedResponse("The response is not HTTP.")
        }
        return (data, http)
    }

    private static func seconds(_ duration: Duration) -> TimeInterval {
        let parts = duration.components
        return TimeInterval(parts.seconds) + TimeInterval(parts.attoseconds) / 1e18
    }
}
