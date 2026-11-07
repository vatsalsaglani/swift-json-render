// Owner: jr-3 (wave 2). Writes for props that may be bound with `$bindState` / `$bindItem`.
internal import JSONRenderCore
internal import JSONRenderSwiftUI

extension JRRenderContext {
    /// Writes `value` through `writer` when prop `name` is bound. Returns `false` when it is
    /// not bound (the component keeps the value in its own view state).
    @MainActor
    func writeBound(_ name: String, _ value: JSONValue, with writer: JRBindingWriter) -> Bool {
        guard let pointer = bindings[name] else { return false }
        writer(pointer, value)
        return true
    }

    /// `true` when prop `name` is bound to state.
    func isBound(_ name: String) -> Bool { bindings[name] != nil }
}
