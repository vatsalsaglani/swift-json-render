extension Spec {
    /// Upstream `nestedToFlat` (`types.ts`): converts a tree whose nodes hold their children
    /// inline into a flat spec.
    ///
    /// - Ids are `el-0`, `el-1`, … in pre-order: a node, then its `children`, then its
    ///   `slots`.
    /// - Only child values that are objects with a `type` key become elements.
    /// - A missing or non-string `type` becomes `"unknown"`; missing `props` become `{}`.
    /// - `children` is always written (empty when there are none); `slots` only when one
    ///   slot exists.
    /// - Other node fields (`visible`, `on`, `repeat`, `watch`) are kept; `state` is not.
    ///   A kept field with a wrong shape is dropped. Unknown fields are dropped, because
    ///   `UIElement` does not model them.
    /// - `state` on the root node, when it is an object, becomes the spec state.
    public static func nestedToFlat(_ nested: JSONValue) -> Spec {
        var elements: [String: UIElement] = [:]
        var counter = 0

        func isNode(_ value: JSONValue) -> Bool {
            if case .object(let members) = value, members["type"] != nil { return true }
            return false
        }

        func walk(_ node: JSONValue) -> String {
            let key = "el-\(counter)"
            counter += 1
            let members = node.objectValue ?? [:]
            var childKeys: [String] = []
            if case .array(let rawChildren)? = members["children"] {
                for child in rawChildren where isNode(child) {
                    childKeys.append(walk(child))
                }
            }
            var slots: [String: [String]] = [:]
            if case .object(let rawSlots)? = members["slots"] {
                for name in rawSlots.keys.sorted() {
                    guard case .array(let slotChildren)? = rawSlots[name] else { continue }
                    slots[name] = slotChildren.filter(isNode).map { walk($0) }
                }
            }
            var element = UIElement(
                type: members["type"]?.stringValue ?? "unknown",
                props: members["props"]?.objectValue ?? [:],
                children: childKeys,
                slots: slots.isEmpty ? nil : slots)
            for field in ["visible", "on", "repeat", "watch"] {
                guard let value = members[field], value != .null else { continue }
                let probe = JSONValue.object(["type": .string(element.type), field: value])
                guard let parsed = try? UIElement(json: probe, id: key) else { continue }
                switch field {
                case "visible": element.visible = parsed.visible
                case "on": element.on = parsed.on
                case "repeat": element.repeat = parsed.repeat
                default: element.watch = parsed.watch
                }
            }
            elements[key] = element
            return key
        }

        let root = walk(nested)
        var spec = Spec(root: root, elements: elements)
        if case .object? = nested["state"] {
            spec.state = nested["state"]
        }
        return spec
    }

    /// Upstream React `flatToTree` (`hooks.ts`): builds a spec from elements that name their
    /// parent.
    ///
    /// Upstream behaviour, kept on purpose: only `type`, `props`, `children` and `visible`
    /// are carried (`slots`, `on`, `repeat` and `watch` are dropped); every element starts
    /// with empty `children`, then children are appended in input order; the last element
    /// without a parent (`nil` or `""`) becomes the root; an element whose parent is missing
    /// is attached nowhere.
    public static func flatToTree(_ elements: [FlatElement]) -> Spec {
        var map: [String: UIElement] = [:]
        var root = ""
        for flat in elements {
            map[flat.key] = UIElement(
                type: flat.element.type, props: flat.element.props, children: [],
                visible: flat.element.visible)
        }
        for flat in elements {
            if let parentKey = flat.parentKey, !parentKey.isEmpty {
                if var parent = map[parentKey] {
                    parent.children = (parent.children ?? []) + [flat.key]
                    map[parentKey] = parent
                }
            } else {
                root = flat.key
            }
        }
        return Spec(root: root, elements: map)
    }
}
