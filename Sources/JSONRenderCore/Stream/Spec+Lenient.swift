// Owner: jr-2 (wave 2).

extension Spec {
    /// The streaming projection of a partial document.
    ///
    /// A document that is not an object gives an empty spec. A missing or non-string `root`
    /// gives `""`; non-object `elements` give no elements; non-object `state` gives `nil`.
    /// Each element is decoded on its own with `UIElement(json:id:)` (the same rules as
    /// `Spec.decode`: unknown keys ignored, single `on`/`watch` bindings normalised). An element
    /// that fails is skipped and reported in `skipped` (id → reason: "not an object",
    /// "no type" or "invalid field"); a parent that lists it sees a dangling id.
    public static func lenient(_ document: JSONValue) -> (spec: Spec, skipped: [String: String]) {
        if let spec = try? Spec(json: document) { return (spec, [:]) }
        guard case .object(let members) = document else {
            return (Spec(root: "", elements: [:]), [:])
        }
        var elements: [String: UIElement] = [:]
        var skipped: [String: String] = [:]
        if case .object(let raw)? = members["elements"] {
            for id in raw.keys.sorted() {
                guard let json = raw[id] else { continue }
                guard case .object(let fields) = json else {
                    skipped[id] = "not an object"
                    continue
                }
                guard case .string? = fields["type"] else {
                    skipped[id] = "no type"
                    continue
                }
                do {
                    elements[id] = try UIElement(json: json, id: id)
                } catch {
                    skipped[id] = "invalid field"
                }
            }
        }
        let root = members["root"]?.stringValue ?? ""
        let state: JSONValue? =
            if case .object? = members["state"] { members["state"] } else { nil }
        return (Spec(root: root, elements: elements, state: state), skipped)
    }
}
