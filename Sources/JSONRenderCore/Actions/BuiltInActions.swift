internal import Foundation

/// The actions every renderer handles without a catalog entry.
///
/// Upstream (`react/src/contexts/actions.tsx`): `setState`, `pushState`, `removeState`,
/// `validateForm`. Swift extensions (documented, listed under EXTENSIONS in the prompt):
/// `toggleState`, `incrementState`. The React-only navigation built-ins `push` and `pop`
/// (`/navStack`, `/currentScreen`) are not implemented: they are not in the spec prompt.
public enum BuiltInAction: String, Sendable, CaseIterable {
    /// `{ statePath, value }`: writes `value` (an undefined value removes the path).
    case setState
    /// `{ statePath, value, clearStatePath? }`: appends `value` to the array at `statePath`
    /// after `deepResolve`, then sets `clearStatePath` to `""`.
    case pushState
    /// `{ statePath, index }`: removes the array element at `index`.
    case removeState
    /// `{ statePath? }`: runs the validation provider and writes `{ valid, errors }` to
    /// `statePath` (default `/formValidation`).
    case validateForm
    /// Extension. `{ statePath }`: a missing or `null` value becomes `true`; any other value
    /// becomes `!isTruthy`.
    case toggleState
    /// Extension. `{ statePath, by? }`: adds `by` (default 1); a non-number current value
    /// counts as 0.
    case incrementState

    /// The four upstream built-ins, in upstream order.
    public static let upstream: [BuiltInAction] = [
        .setState, .pushState, .removeState, .validateForm,
    ]
    /// The Swift extensions.
    public static let extensions: [BuiltInAction] = [.toggleState, .incrementState]

    /// `true` for `toggleState` and `incrementState`.
    public var isExtension: Bool { BuiltInAction.extensions.contains(self) }

    /// The default `validateForm` result path.
    public static let defaultValidationPath: JSONPointer = "/formValidation"

    /// Upstream `deepResolveValue` for `pushState` values:
    /// `"$id"` and a single-key `{ "$id": … }` become a new unique id (a UUID string; upstream
    /// uses a timestamp and a counter), a single-key `{ "$state": "/p" }` reads state, and
    /// arrays and objects recurse. A reference to a missing path is dropped from an object
    /// and becomes `null` in an array.
    public static func deepResolve(_ value: JSONValue?, state: JSONValue) -> JSONValue? {
        deepResolve(value, state: state, makeID: { UUID().uuidString })
    }

    /// `deepResolve` with a custom id source (for tests).
    public static func deepResolve(
        _ value: JSONValue?, state: JSONValue, makeID: () -> String
    ) -> JSONValue? {
        guard let value else { return nil }
        switch value {
        case .string("$id"):
            return .string(makeID())
        case .array(let items):
            return .array(items.map { deepResolve($0, state: state, makeID: makeID) ?? .null })
        case .object(let members):
            if members.count == 1 {
                if case .string(let path)? = members["$state"] {
                    return state.value(at: JSONPointer(lenient: path))
                }
                if members["$id"] != nil {
                    return .string(makeID())
                }
            }
            var resolved: [String: JSONValue] = [:]
            for (key, member) in members {
                if let item = deepResolve(member, state: state, makeID: makeID) {
                    resolved[key] = item
                }
            }
            return .object(resolved)
        default:
            return value
        }
    }

    /// The state changes for the pure state built-ins (all but `validateForm`), computed
    /// from the current state. Empty when the params are unusable (for example a missing,
    /// empty or `__proto__` `statePath`).
    static func changes(
        for action: BuiltInAction, params: [String: JSONValue?], state: JSONValue
    ) -> [(JSONPointer, JSONValue?)] {
        guard let path = statePath(params["statePath"]) else { return [] }
        switch action {
        case .setState:
            return [(path, param(params, "value"))]
        case .pushState:
            let item = deepResolve(param(params, "value"), state: state) ?? .null
            let current = state.value(at: path)?.arrayValue ?? []
            var changes: [(JSONPointer, JSONValue?)] = [(path, .array(current + [item]))]
            if let clear = statePath(params["clearStatePath"]) {
                changes.append((clear, .string("")))
            }
            return changes
        case .removeState:
            guard case .number(let raw)? = param(params, "index"),
                case .array(let items)? = state.value(at: path)
            else { return [] }
            let kept = items.enumerated().filter { Double($0.offset) != raw }.map(\.element)
            return [(path, .array(kept))]
        case .toggleState:
            let current = state.value(at: path)
            let next: Bool
            switch current {
            case nil, .null?: next = true
            case let value?: next = !value.isTruthy
            }
            return [(path, .bool(next))]
        case .incrementState:
            let by = param(params, "by")?.numberValue ?? 1
            let current = state.value(at: path)?.numberValue ?? 0
            return [(path, .number(current + by))]
        case .validateForm:
            return []
        }
    }

    static func param(_ params: [String: JSONValue?], _ key: String) -> JSONValue? {
        params[key] ?? nil
    }

    /// A usable state path: a non-empty string without `__proto__`.
    static func statePath(_ value: JSONValue??) -> JSONPointer? {
        guard case .string(let string)?? = value, !string.isEmpty,
            let pointer = try? JSONPointer(string)
        else { return nil }
        return pointer
    }
}
