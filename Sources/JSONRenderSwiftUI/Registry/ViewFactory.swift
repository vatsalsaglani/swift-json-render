// Owner: jr-1b (wave 1). Frozen after wave 1.
public import JSONRenderCore
public import SwiftUI

/// The one type-erasure point of the renderer: it turns a render context into a view.
/// One `AnyView` per element at this boundary; none in the hot path below it.
public struct ViewFactory: ComponentRenderer {
    public let make: @MainActor @Sendable (JRRenderContext) -> AnyView

    public init(_ make: @escaping @MainActor @Sendable (JRRenderContext) -> AnyView) {
        self.make = make
    }
}
