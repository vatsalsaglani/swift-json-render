internal import Foundation
// Owner: jr-3 (wave 2). The computed accessibility label of every drawn element.
internal import JSONRenderCore

/// Lists the label each drawn element gets from its spec props, without the system
/// accessibility tree (no synthetic input, no running app needed).
///
/// The label is the first non-empty string of `label`, `title`, `text`, `alt`, `name`,
/// `trigger`; else the item labels of `tabs`, `items` or `buttons` (each item's `label` or
/// `title`, as the views draw them); else "Page of N" for `totalPages`. An element is a control when it binds a prop, binds an event, or has a
/// control type. A control without a label is a finding.
public enum AccessibilityAudit {
    /// The prop names a label comes from, in priority order.
    public static let labelProps = ["label", "title", "text", "alt", "name", "trigger"]

    /// Types that are interactive even without bindings.
    public static let controlTypes: Set<String> = [
        "Button", "Link", "Input", "Textarea", "Select", "Checkbox", "Radio", "Switch", "Slider",
        "Toggle", "ToggleGroup", "ButtonGroup", "Tabs", "Accordion", "Collapsible", "Pagination",
        "Popover", "DropdownMenu", "Dialog", "Drawer",
    ]

    public struct Entry: Sendable, Hashable {
        public let id: String
        public let type: String
        /// `nil` when no label prop has text.
        public let label: String?
        public let isControl: Bool

        /// A control with no label.
        public var isMissingLabel: Bool { isControl && label == nil }
    }

    /// One entry per drawn element, in draw order.
    public static func entries(in walk: RenderWalk) -> [Entry] {
        walk.elements.map { element in
            let label =
                labelProps.lazy.compactMap { name -> String? in
                    guard case .string(let text)?? = element.props[name] else { return nil }
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? nil : trimmed
                }.first ?? itemLabels(element.props) ?? pageLabel(element.props)
            let isControl =
                controlTypes.contains(element.type) || !element.bindings.isEmpty
                || !element.events.isEmpty
            return Entry(id: element.id, type: element.type, label: label, isControl: isControl)
        }
    }

    private static func itemLabels(_ props: [String: JSONValue?]) -> String? {
        for name in ["tabs", "items", "buttons"] {
            guard case .array(let items)?? = props[name] else { continue }
            let labels = items.compactMap { item -> String? in
                (item["label"] ?? item["title"])?.stringValue
            }.filter { !$0.isEmpty }
            if !labels.isEmpty { return labels.joined(separator: ", ") }
        }
        return nil
    }

    private static func pageLabel(_ props: [String: JSONValue?]) -> String? {
        guard case .number(let total)?? = props["totalPages"] else { return nil }
        return "Page of \(JSONValue.number(total).jsString)"
    }
}
