import Foundation
import JSONRenderCore
import JSONRenderSwiftUI
import Observation
import os
import Testing

/// The upstream fixtures, located from this file's path.
enum Fixtures {
    static let upstream: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // JSONRenderSwiftUITests
        .deletingLastPathComponent()  // Tests
        .appendingPathComponent("ParityFixtures/upstream")

    /// The eight example specs, in upstream index order.
    static let specNames = [
        "confetti", "user-profile-card", "settings-form", "pricing-table", "status-dashboard",
        "feature-comparison", "registration-form", "cascading-selects",
    ]

    static func spec(_ name: String) throws -> Spec {
        let data = try Data(contentsOf: upstream.appendingPathComponent("specs/\(name).json"))
        return try Spec.decode(data).spec
    }

    static func text(_ relativePath: String) throws -> String {
        try String(contentsOf: upstream.appendingPathComponent(relativePath), encoding: .utf8)
    }
}

/// Records dispatches (names and element ids only) in order.
final class RecordingObserver: ActionObserver {
    private let log = OSAllocatedUnfairLock<[String]>(initialState: [])

    func dispatched(_ info: ActionDispatchInfo) {
        log.withLock { $0.append("\(info.elementID ?? "-"):\(info.name)") }
    }

    func settled(_ info: ActionSettleInfo) {
        log.withLock { $0.append("\(info.elementID ?? "-"):\(info.name):\(info.outcome.rawValue)") }
    }

    var entries: [String] { log.withLock { $0 } }
}

/// A host that declines every confirmation.
struct DecliningHost: ActionHost {
    func confirm(_ confirm: ActionConfirm, action: String) async -> Bool { false }
    func navigate(_ path: String) async {}
    func openURL(_ url: URL) async -> Bool { false }
}

/// Waits for the next change of anything `read` reads on an observable object.
@MainActor
func nextChange(_ read: @escaping @MainActor () -> Void) async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        let once = OSAllocatedUnfairLock(initialState: false)
        withObservationTracking {
            read()
        } onChange: {
            let first = once.withLock { done in
                defer { done = true }
                return !done
            }
            if first { continuation.resume() }
        }
    }
}

/// Waits until the store holds `value` at `pointer` (via the store's own stream).
func waitForState(_ store: StateStore, _ pointer: JSONPointer, equals value: JSONValue) async {
    for await snapshot in await store.snapshots(bufferingPolicy: .unbounded) {
        if snapshot.state.value(at: pointer) == value { return }
    }
}

/// Waits until `condition` holds, re-checking on each change of what it reads.
@MainActor
func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
    while !condition() {
        await nextChange { _ = condition() }
    }
}
