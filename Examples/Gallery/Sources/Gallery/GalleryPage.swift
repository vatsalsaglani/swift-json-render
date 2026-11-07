// Owner: jr-3 (Gallery shell). The page contract every agent's pages conform to.
import SwiftUI

/// The sidebar groups, in sidebar order.
public enum GalleryGroup: String, CaseIterable, Sendable {
    case components, inputs, charts, streaming, theme, accessibility

    public var title: String {
        switch self {
        case .components: "Components"
        case .inputs: "Inputs"
        case .charts: "Charts"
        case .streaming: "Streaming"
        case .theme: "Theme"
        case .accessibility: "Accessibility"
        }
    }
}

/// One Gallery page. Register it with one line in `GalleryPages.all`.
///
/// Build the body with `GalleryPageLayout` and `SpecExample` so the page looks like the
/// others and snapshots headlessly (no window-only API, no sheets on screen).
@MainActor public protocol GalleryPage: View {
    static var title: String { get }
    static var group: GalleryGroup { get }
    init()
}
