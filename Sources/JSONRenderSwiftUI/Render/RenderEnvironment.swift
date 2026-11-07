// Owner: jr-3 (wave 2). Environment values the renderer sets for components.
public import Foundation
public import JSONRenderCore
public import SwiftUI

extension EnvironmentValues {
    /// The model of the enclosing `JSONRenderView`.
    @Entry public var jrRenderModel: RenderModel? = nil
    /// The repeat row an element renders in.
    @Entry public var jrRepeatScope: RepeatScope? = nil
    /// The rows of the enclosing `repeat` element, set on that element's view only (its
    /// children are repeated per row). A component that lays rows out itself, such as a
    /// Table, reads it; others ignore it.
    @Entry public var jrRepeatRows: JRRepeatRows? = nil
    /// The form validator of the enclosing `JSONRenderView` (fields register here).
    @Entry public var jrFormValidator: FormValidator? = nil
    /// The element that owns the default keyboard action (the first primary Button).
    @Entry public var jrDefaultActionElementID: String? = nil
    /// The event names the current element binds in its `on` field.
    @Entry public var jrElementEvents: Set<String> = []
    /// Opens a link through the action host.
    @Entry public var jrURLOpener: JRURLOpener = .none
    /// `true` inside a Card body (a nested card draws no shadow).
    @Entry public var jrInsideCard: Bool = false
    /// `true` inside a presented Dialog or Drawer (a nested one draws inline).
    @Entry public var jrInsidePresentation: Bool = false
    /// The element ids from the root to the current element (cycle guard).
    @Entry var jrAncestors: Set<String> = []
}

/// Opens a URL through the host. Equal when `id` is equal (see `JRRenderChild`).
public struct JRURLOpener: Sendable, Equatable {
    public let id: UUID
    public let open: @MainActor (URL) -> Void

    public init(id: UUID = UUID(), _ open: @escaping @MainActor (URL) -> Void) {
        self.id = id
        self.open = open
    }

    @MainActor public func callAsFunction(_ url: URL) { open(url) }

    public static func == (lhs: JRURLOpener, rhs: JRURLOpener) -> Bool { lhs.id == rhs.id }

    /// Opens nothing.
    public static let none = JRURLOpener(
        id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    ) { _ in }
}

/// Maps the spec `size` prop to a control size.
public enum JRControlSize {
    /// `sm` → `.small`, `lg` → `.large`, anything else → `nil` (keep the inherited size).
    public static func controlSize(for size: String?) -> ControlSize? {
        switch size {
        case "sm": .small
        case "lg": .large
        case "md": .regular
        default: nil
        }
    }
}

extension View {
    /// Applies the control size for a spec `size` prop; keeps the inherited size for `nil`
    /// or an unknown value.
    @ViewBuilder
    public func jrControlSize(_ size: String?) -> some View {
        if let controlSize = JRControlSize.controlSize(for: size) {
            self.controlSize(controlSize)
        } else {
            self
        }
    }
}
