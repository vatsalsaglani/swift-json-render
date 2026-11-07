/// How a model edits an existing spec (upstream `edit-modes.ts`).
public enum EditMode: String, Sendable, Hashable, CaseIterable {
    /// RFC 6902 JSON Patch, one operation per line.
    case patch
    /// RFC 7396 JSON Merge Patch.
    case merge
    /// A unified diff against the serialised spec.
    case diff
}

/// Upstream `buildEditInstructions` and `buildEditUserPrompt`, JSON format only (the YAML
/// variant is not ported).
public enum EditInstructions {
    /// The system-prompt section for `modes` (`["patch"]` when empty).
    public static func build(_ modes: [EditMode]) -> String {
        let modes = modes.isEmpty ? [EditMode.patch] : modes
        var sections = ["EDITING EXISTING SPECS:", ""]
        let guidance = selectionGuidance(modes)
        if !guidance.isEmpty {
            sections.append(guidance)
            sections.append("")
        }
        for mode in modes {
            sections.append(instructions(mode))
            sections.append("")
        }
        return sections.joined(separator: "\n")
    }

    static func instructions(_ mode: EditMode) -> String {
        switch mode {
        case .patch:
            [
                "PATCH MODE (RFC 6902 JSON Patch):",
                "Output one JSON object per line. Each line is a patch operation.",
                "- Add: {\"op\":\"add\",\"path\":\"/elements/new-key\",\"value\":{...}}",
                "- Replace: {\"op\":\"replace\",\"path\":\"/elements/existing-key\",\"value\":{...}}",
                "- Remove: {\"op\":\"remove\",\"path\":\"/elements/old-key\"}",
                "Only output patches for what needs to change.",
            ].joined(separator: "\n")
        case .merge:
            [
                "MERGE MODE (RFC 7396 JSON Merge Patch):",
                "Output a single JSON object on one line with __json_edit set to true.",
                "Include only the keys that changed. Unmentioned keys are preserved.",
                "Set a key to null to delete it.",
                "",
                "Example (update a title and add an element):",
                "{\"__json_edit\":true,\"elements\":{\"main\":{\"props\":{\"title\":\"New Title\"}},\"new-el\":{\"type\":\"Card\",\"props\":{},\"children\":[]}}}",
                "",
                "Example (delete an element):",
                "{\"__json_edit\":true,\"elements\":{\"old-widget\":null}}",
            ].joined(separator: "\n")
        case .diff:
            [
                "DIFF MODE (unified diff):",
                "Output a unified diff inside a ```diff code fence.",
                "The diff applies against the JSON-serialized current spec.",
                "",
                "Example:",
                "```diff",
                "--- a/spec.json",
                "+++ b/spec.json",
                "@@ -3,1 +3,1 @@",
                "-      \"title\": \"Login\"",
                "+      \"title\": \"Welcome Back\"",
                "```",
            ].joined(separator: "\n")
        }
    }

    static func selectionGuidance(_ modes: [EditMode]) -> String {
        guard modes.count > 1 else { return "" }
        var parts = ["Choose the best edit strategy for the requested change:"]
        if modes.contains(.patch) {
            parts.append("- PATCH: best for precise, targeted single-field updates")
        }
        if modes.contains(.merge) {
            parts.append(
                "- MERGE: best for structural changes (add/remove elements, reparent children, update multiple props at once)"
            )
        }
        if modes.contains(.diff) {
            parts.append(
                "- DIFF: best for small text-level changes when you can see the exact lines to change"
            )
        }
        return parts.joined(separator: "\n")
    }

    /// Upstream `buildEditUserPrompt` (JSON format). `userText` is already truncated.
    static func userPrompt(_ userText: String, spec: Spec, modes: [EditMode]) -> String {
        let modes = modes.isEmpty ? [EditMode.patch] : modes
        let specText = UserPrompt.ordered(spec).prettyStringified
        var parts: [String] = []
        if modes.contains(.diff) {
            parts += [
                "CURRENT UI STATE (line numbers for reference):", "```", numbered(specText),
                "```",
            ]
        } else {
            parts += [
                "CURRENT UI STATE (already loaded, DO NOT recreate existing elements):", "```",
                specText, "```",
            ]
        }
        parts += ["", "USER REQUEST: \(userText)", ""]
        if modes.count == 1 {
            switch modes[0] {
            case .patch: parts.append("Output ONLY the JSON Patch lines needed for the change.")
            case .merge:
                parts.append(
                    "Output ONLY a single JSON merge line with __json_edit set to true. Include only keys that need to change."
                )
            case .diff: parts.append("Output ONLY the unified diff in a ```diff fence.")
            }
        } else {
            let names = modes.map { mode in
                switch mode {
                case .patch: "JSON Patch lines"
                case .merge: "JSON merge line (__json_edit)"
                case .diff: "```diff fence"
                }
            }
            parts.append(
                "Choose the best edit strategy and output using one of: \(names.joined(separator: ", "))"
            )
        }
        return parts.joined(separator: "\n")
    }

    /// Upstream `addLineNumbers`: `"%{width}d| line"`.
    static func numbered(_ text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let width = String(lines.count).count
        return lines.enumerated().map { index, line in
            let number = String(index + 1)
            return String(repeating: " ", count: width - number.count) + number + "| " + line
        }.joined(separator: "\n")
    }
}
