import Observation

/// Waits, without polling, until `read()` satisfies `predicate`. It re-reads only when an
/// observed property changes.
@MainActor
func observe<T>(_ read: @escaping @MainActor () -> T, until predicate: (T) -> Bool) async -> T {
    while true {
        let value = read()
        if predicate(value) { return value }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            withObservationTracking {
                _ = read()
            } onChange: {
                continuation.resume()
            }
        }
    }
}

/// A test error with a fixed type name.
struct StreamTestError: Error {}

/// A main-actor box for values a test closure records.
@MainActor
final class Recorder<Value> {
    var values: [Value] = []
}
