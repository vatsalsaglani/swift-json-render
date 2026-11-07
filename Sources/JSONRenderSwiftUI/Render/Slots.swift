// Owner: jr-3 (wave 2). The slot vocabulary.
public import JSONRenderCore

/// The slot vocabulary. A slot is a list of child element ids; components declare the
/// names they accept in `ComponentDefinition.slots`.
///
/// - `header`, `footer`, `leading`, `trailing`: regions around the content.
/// - `empty`: drawn when the component decides it has no content (a Table with no rows).
/// - `loading`: drawn while the stream phase is `.streaming` and the component has no
///   content yet.
/// - `error`: drawn when content failed (an image that did not load).
///
/// `default` is a synonym for `children`; a spec that uses it gets a warning, as upstream.
public enum JRSlots {
    public static let defaultSlot = "default"
    public static let header = "header"
    public static let footer = "footer"
    public static let leading = "leading"
    public static let trailing = "trailing"
    public static let empty = "empty"
    public static let loading = "loading"
    public static let error = "error"

    /// The named slots, in a fixed order.
    public static let vocabulary = [header, footer, leading, trailing, empty, loading, error]
}

extension JRRenderContext {
    /// The children of slot `name`, or `nil` when the spec gives the slot no ids.
    public func slot(_ name: String) -> JRChildren? {
        guard let children = slots[name], !children.isEmpty else { return nil }
        return children
    }
}
