public import Foundation

/// A catalog action handler. It receives the resolved params (`nil` = undefined) and the
/// host. A thrown error triggers the binding's `onError`.
public typealias ActionHandler =
    @Sendable (_ params: [String: JSONValue?], _ host: any ActionHost) async throws -> JSONValue?

/// The app side of action execution: dialogs, navigation and links. Every user-visible
/// effect goes through the host, so the host stays in control.
public protocol ActionHost: Sendable {
    /// Shows the confirmation and returns `true` when the user confirms.
    func confirm(_ confirm: ActionConfirm, action: String) async -> Bool
    /// Handles `onSuccess: { navigate }`.
    func navigate(_ path: String) async
    /// Opens a link. Returns `true` when the host opened it.
    func openURL(_ url: URL) async -> Bool
}

/// A host that confirms everything, ignores navigation and opens nothing. For tests and
/// headless use.
public struct NoopActionHost: ActionHost {
    public init() {}

    public func confirm(_ confirm: ActionConfirm, action: String) async -> Bool { true }
    public func navigate(_ path: String) async {}
    public func openURL(_ url: URL) async -> Bool { false }
}

/// A catalog action (upstream `ActionDefinition`).
public struct ActionDefinition: Sendable {
    /// The params shape, for the generated prompt.
    public var params: PropSchema
    /// The description, for the generated prompt.
    public var description: String
    /// The handler. `nil` declares the action for the prompt; the host supplies the handler
    /// later. Dispatching an action without a handler does nothing (upstream warns).
    public var handler: ActionHandler?

    public init(
        params: PropSchema = .object([]), description: String = "", handler: ActionHandler? = nil
    ) {
        self.params = params
        self.description = description
        self.handler = handler
    }
}

/// An error with a message for `onError: { set: { "/p": "$error.message" } }`. Handlers
/// may throw any error; this type makes the message explicit.
public struct ActionFailure: Error, Sendable, Hashable, CustomStringConvertible {
    public var message: String

    public init(_ message: String) {
        self.message = message
    }

    public var description: String { message }

    /// The text that replaces `"$error.message"`: `ActionFailure.message`, then
    /// `LocalizedError.errorDescription`, then `String(describing:)`.
    public static func message(of error: any Error) -> String {
        if let failure = error as? ActionFailure { return failure.message }
        if let localized = error as? any LocalizedError, let text = localized.errorDescription {
            return text
        }
        return String(describing: error)
    }
}
