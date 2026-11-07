// Owner: jr-1b (wave 1). Frozen after wave 1.
public import Foundation
public import JSONRenderCore
public import SwiftUI

/// Renders one child element by id. jr-3's renderer sets it in the environment.
///
/// A struct, not a bare closure: SwiftUI cannot compare closures, so a closure environment
/// value would invalidate every reader on each update. Two values are equal when their `id`
/// is equal; give a new `id` only when the rendering function really changes.
public struct JRRenderChild: Sendable, Equatable {
    public let id: UUID
    public let render: @MainActor (String) -> AnyView

    public init(id: UUID = UUID(), _ render: @escaping @MainActor (String) -> AnyView) {
        self.id = id
        self.render = render
    }

    @MainActor public func callAsFunction(_ elementID: String) -> AnyView { render(elementID) }

    public static func == (lhs: JRRenderChild, rhs: JRRenderChild) -> Bool { lhs.id == rhs.id }

    /// Draws nothing.
    public static let empty = JRRenderChild(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    ) { _ in AnyView(EmptyView()) }
}

extension EnvironmentValues {
    /// The child renderer. The default draws nothing.
    @Entry public var jrRenderChild: JRRenderChild = .empty
}

extension JRChildren: View {
    /// The children in order. Identity is the element id.
    public var body: some View {
        JRChildrenView(ids: ids)
    }
}

/// Reads the child renderer from the environment (an extension cannot hold `@Environment`).
struct JRChildrenView: View {
    let ids: [String]
    @Environment(\.jrRenderChild) private var renderChild

    var body: some View {
        ForEach(ids, id: \.self) { id in
            renderChild(id)
        }
    }
}
