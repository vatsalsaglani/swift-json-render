// Owner: jr-3 (wave 2); seeded by jr-1b.
public import Foundation
public import JSONRenderCore
public import SwiftUI

/// Writes a bound value (`$bindState` / `$bindItem`) to the state store. The renderer sets
/// it in the environment. Equal when `id` is equal (see `JRRenderChild` for why).
public struct JRBindingWriter: Sendable, Equatable {
    public let id: UUID
    public let write: @MainActor (JSONPointer, JSONValue) -> Void

    public init(id: UUID = UUID(), _ write: @escaping @MainActor (JSONPointer, JSONValue) -> Void) {
        self.id = id
        self.write = write
    }

    @MainActor public func callAsFunction(_ pointer: JSONPointer, _ value: JSONValue) {
        write(pointer, value)
    }

    public static func == (lhs: JRBindingWriter, rhs: JRBindingWriter) -> Bool {
        lhs.id == rhs.id
    }

    /// Does nothing.
    public static let none = JRBindingWriter(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    ) { _, _ in }
}

extension EnvironmentValues {
    /// The binding writer. The default does nothing.
    @Entry public var jrWriteBinding: JRBindingWriter = .none
}
