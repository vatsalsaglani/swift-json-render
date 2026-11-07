/// The result of `Catalog.autoFixReport`.
public struct AutoFixResult: Sendable, Hashable {
    public var spec: Spec
    public var fixes: [SpecFix]

    /// The fix messages (upstream `fixes`).
    public var messages: [String] { fixes.map(\.message) }
}

extension Catalog {
    /// Upstream `autoFixSpec`: the fixed spec and the fix messages.
    public static func autoFix(_ spec: Spec, lossy: Bool = true) -> (Spec, fixes: [String]) {
        let result = autoFixReport(spec, lossy: lossy)
        return (result.spec, result.messages)
    }

    /// The brief's first shape. `report` is not read: the fixes come from the spec itself.
    @available(*, deprecated, message: "Use autoFix(_:lossy:); the report is not read.")
    public static func autoFix(_ spec: Spec, report: ValidationReport?, lossy: Bool = true)
        -> (Spec, fixes: [String])
    {
        autoFix(spec, lossy: lossy)
    }

    /// Upstream `autoFixSpec` with the structured fix list.
    ///
    /// Lossless fixes move `visible`, `on`, `repeat` and `watch` from `props` to the element
    /// (a moved value replaces an existing element field, as upstream). Lossy fixes (only when
    /// `lossy` is `true`) drop child and slot references to undefined elements; a repeat
    /// container whose every child is undefined keeps them, so repair targets the missing
    /// template.
    ///
    /// Deviations: elements are processed in id order. An `on`, `watch` or `repeat` value in
    /// `props` that does not parse as a binding map or repeat config stays in `props` and no
    /// fix is recorded (Swift cannot store the malformed value on the element).
    public static func autoFixReport(_ spec: Spec, lossy: Bool = true) -> AutoFixResult {
        var fixes: [SpecFix] = []
        var elements = spec.elements
        let keys = elements.keys.sorted()
        for key in keys {
            guard var element = elements[key] else { continue }
            func moved(_ field: String) {
                fixes.append(
                    SpecFix(
                        message: "Moved \"\(field)\" from props to element level on \"\(key)\".",
                        lossy: false))
            }
            if let raw = element.props["visible"] {
                element.props["visible"] = nil
                element.visible = VisibilityCondition(json: raw)
                moved("visible")
            }
            if let raw = element.props["on"],
                let parsed = try? UIElement(json: ["type": "", "on": raw]).on
            {
                element.props["on"] = nil
                element.on = parsed
                moved("on")
            }
            if let raw = element.props["repeat"], let parsed = try? RepeatConfig(json: raw, id: key)
            {
                element.props["repeat"] = nil
                element.repeat = parsed
                moved("repeat")
            }
            if let raw = element.props["watch"],
                let parsed = try? UIElement(json: ["type": "", "watch": raw]).watch
            {
                element.props["watch"] = nil
                element.watch = parsed
                moved("watch")
            }
            elements[key] = element
        }
        if lossy {
            for key in keys {
                guard var element = elements[key], let children = element.children,
                    !children.isEmpty
                else { continue }
                let present = children.filter { elements[$0] != nil }
                guard present.count != children.count else { continue }
                if element.repeat != nil, present.isEmpty { continue }
                for child in children where elements[child] == nil {
                    fixes.append(
                        SpecFix(
                            message:
                                "Removed reference to undefined element \"\(child)\" from children of \"\(key)\".",
                            lossy: true))
                }
                element.children = present
                elements[key] = element
            }
            for key in keys {
                guard var element = elements[key], let slots = element.slots else { continue }
                var changed = false
                var fixedSlots: [String: [String]] = [:]
                for name in slots.keys.sorted() {
                    let ids = slots[name] ?? []
                    let present = ids.filter { elements[$0] != nil }
                    if present.count != ids.count {
                        changed = true
                        for child in ids where elements[child] == nil {
                            fixes.append(
                                SpecFix(
                                    message:
                                        "Removed reference to undefined element \"\(child)\" from slot \"\(name)\" of \"\(key)\".",
                                    lossy: true))
                        }
                    }
                    fixedSlots[name] = present
                }
                if changed {
                    element.slots = fixedSlots
                    elements[key] = element
                }
            }
        }
        return AutoFixResult(
            spec: Spec(root: spec.root, elements: elements, state: spec.state), fixes: fixes)
    }
}
