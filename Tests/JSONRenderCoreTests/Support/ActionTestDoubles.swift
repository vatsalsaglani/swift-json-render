import Foundation

@testable import JSONRenderCore

/// Records calls in order. Handlers and hosts append to it.
actor CallLog {
    struct Call: Equatable, Sendable {
        let fn: String
        let args: [JSONValue]
    }

    private(set) var calls: [Call] = []

    func append(_ fn: String, _ args: [JSONValue]) {
        calls.append(Call(fn: fn, args: args))
    }
}

/// A host that records confirmations and navigation and answers confirmations with a
/// fixed value.
actor RecordingHost: ActionHost {
    let answer: Bool
    let log: CallLog?
    private(set) var confirmations: [(action: String, title: String, message: String)] = []
    private(set) var navigations: [String] = []

    init(answer: Bool = true, log: CallLog? = nil) {
        self.answer = answer
        self.log = log
    }

    func confirm(_ confirm: ActionConfirm, action: String) async -> Bool {
        confirmations.append((action, confirm.title, confirm.message))
        return answer
    }

    func navigate(_ path: String) async {
        navigations.append(path)
        await log?.append("navigate", [.string(path)])
    }

    func openURL(_ url: URL) async -> Bool { false }
}

/// An observer that forwards events into a stream.
struct StreamObserver: ActionObserver {
    enum Event: Sendable {
        case dispatched(ActionDispatchInfo)
        case settled(ActionSettleInfo)
    }

    let continuation: AsyncStream<Event>.Continuation

    func dispatched(_ info: ActionDispatchInfo) { continuation.yield(.dispatched(info)) }
    func settled(_ info: ActionSettleInfo) { continuation.yield(.settled(info)) }

    static func make() -> (StreamObserver, AsyncStream<Event>) {
        let (stream, continuation) = AsyncStream.makeStream(of: Event.self)
        return (StreamObserver(continuation: continuation), stream)
    }
}

/// A fixed validation outcome.
struct FixedValidation: FormValidationProvider {
    let outcome: FormValidationOutcome

    func validateAll(state: JSONValue) async -> FormValidationOutcome { outcome }
}

extension Dictionary where Key == String, Value == JSONValue? {
    /// Drops undefined values.
    var defined: [String: JSONValue] { compactMapValues { $0 } }
}
