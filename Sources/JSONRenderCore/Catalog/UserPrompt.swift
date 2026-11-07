/// Upstream `buildUserPrompt` (`prompt.ts`), JSON format only.
public enum UserPrompt {
    /// Builds the user message. With a non-empty `currentSpec` it is an edit prompt;
    /// otherwise a fresh-generation prompt. `state` is appended when it is a non-empty
    /// object. `maxPromptLength` truncates the user text (in UTF-16 units, never splitting
    /// a character).
    ///
    /// Serialised specs and state use 2-space JSON with members in a fixed order: spec
    /// `root, elements, state`; elements by id; element fields `type, props, children,
    /// slots, visible, on, repeat, watch`; other objects by key. Upstream uses insertion
    /// order, which Swift values do not keep.
    public static func build(
        prompt: String, currentSpec: Spec? = nil, state: JSONValue? = nil,
        maxPromptLength: Int? = nil, editModes: [EditMode] = [.patch]
    ) -> String {
        var userText = prompt
        if let maxPromptLength, maxPromptLength > 0 { userText = truncate(prompt, maxPromptLength) }
        let stateText: String? = {
            guard case .object(let members)? = state, !members.isEmpty, let state else {
                return nil
            }
            return OrderedJSON(state).prettyStringified
        }()
        if let currentSpec, !currentSpec.elements.isEmpty {
            let edit = EditInstructions.userPrompt(userText, spec: currentSpec, modes: editModes)
            if let stateText { return "\(edit)\n\nAVAILABLE STATE:\n\(stateText)" }
            return edit
        }
        var parts = [userText]
        if let stateText { parts.append("\nAVAILABLE STATE:\n\(stateText)") }
        parts.append(
            "\nRemember: Output /root first, then interleave /elements and /state patches so the UI fills in progressively as it streams. Output each state patch right after the elements that use it, one per array item."
        )
        return parts.joined(separator: "\n")
    }

    static func truncate(_ text: String, _ limit: Int) -> String {
        var units = 0
        var result = ""
        for character in text {
            units += character.utf16.count
            if units > limit { break }
            result.append(character)
        }
        return result
    }

    /// The spec in the fixed member order described on `build`.
    static func ordered(_ spec: Spec) -> OrderedJSON {
        var members: [(String, OrderedJSON)] = [
            ("root", .string(spec.root)),
            (
                "elements",
                .object(
                    spec.elements.keys.sorted().compactMap { id in
                        spec.elements[id].map { (id, ordered($0)) }
                    })
            ),
        ]
        if let state = spec.state { members.append(("state", OrderedJSON(state))) }
        return .object(members)
    }

    static func ordered(_ element: UIElement) -> OrderedJSON {
        let json = element.jsonValue
        let order = ["type", "props", "children", "slots", "visible", "on", "repeat", "watch"]
        return .object(
            order.compactMap { key in json[key].map { (key, OrderedJSON($0)) } })
    }
}
