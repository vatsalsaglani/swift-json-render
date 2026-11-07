// Owner: jr-2 (wave 2); seeded by jr-1b. Append-only.
public import SwiftUI

/// Where a streamed spec is in its life.
public enum JRStreamPhase: Sendable, Hashable {
    case idle, streaming, stopped, final
}

extension EnvironmentValues {
    /// The stream phase of the enclosing render. Default: `.idle`.
    @Entry public var jrStreamPhase: JRStreamPhase = .idle
}
