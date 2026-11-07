internal import JSONRenderCore

/// What a step records about the answers it used.
struct AnswerNotes: Sendable, Hashable {
    var refused: [String] = []
    var fallbacks: [String] = []

    /// A refused question also used its fallback.
    mutating func refuse(_ name: String) {
        refused.append(name)
        fallbacks.append(name)
    }

    mutating func fallBack(_ name: String) {
        fallbacks.append(name)
    }
}

/// Reads answers against their questions. An answer that is refused, has the wrong type,
/// names a value that was not offered, or carries a number out of range is a refusal.
struct AnswerReader {
    let limits: ComposeLimits
    var notes = AnswerNotes()

    /// An accepted choice value, or `nil` (the caller uses its fallback).
    mutating func choice(_ answer: DecisionAnswer, offered: Set<String>) -> String? {
        guard case .choice(let name, let value, _, let confidence) = answer,
            offered.contains(value), Self.isUnit(confidence)
        else {
            notes.refuse(answer.name)
            return nil
        }
        guard confidence >= limits.choiceConfidence else {
            notes.fallBack(name)
            return nil
        }
        return value
    }

    /// Whether a predicate includes its candidate. A refusal leaves it out.
    mutating func predicate(_ answer: DecisionAnswer) -> Bool {
        guard case .predicate(_, let probability) = answer, Self.isUnit(probability) else {
            notes.refuse(answer.name)
            return false
        }
        return probability >= limits.includeProbability
    }

    /// The density level index (0 sparse, 1 normal, 2 dense). A refusal or a confidence
    /// below the threshold uses `normal`. Ties round to the sparser level: the density only
    /// lowers the budget.
    mutating func densityLevel(_ answer: DecisionAnswer, levels: Int) -> Int {
        let fallback = min(1, levels - 1)
        guard case .score(let name, let score, _, let confidence) = answer,
            score.isFinite, score >= 0, score <= Double(levels - 1), Self.isUnit(confidence)
        else {
            notes.refuse(answer.name)
            return fallback
        }
        guard confidence >= limits.choiceConfidence else {
            notes.fallBack(name)
            return fallback
        }
        return Self.level(for: score, levels: levels)
    }

    /// Rounds half down: 0.5 → 0, 1.5 → 1, 1.56 → 2.
    static func level(for score: Double, levels: Int) -> Int {
        min(max(Int((score - 0.5).rounded(.up)), 0), levels - 1)
    }

    static func isUnit(_ value: Double) -> Bool {
        value.isFinite && value >= 0 && value <= 1
    }
}

/// The outcome of the selection round.
struct Selection: Sendable {
    var root: CompositionCandidate
    var selected: [CompositionCandidate]
    var limited: Bool
}

enum CompositionApply {
    /// Applies the membership answers exactly as upstream `composeBatch` does, with the
    /// density cap in place of `maxElements` when it is lower.
    static func select(
        root: CompositionCandidate, groups: [CandidateGroup], answers: [String: DecisionAnswer],
        reader: inout AnswerReader, budget: Int, catalog: Catalog, limits: ComposeLimits
    ) -> Selection {
        var selected = [root]
        let rootSlots = catalog.component(named: root.element.type)?.slots ?? []
        var limited = false
        for group in groups {
            let first = group.first
            if let resource = first.resource, resource == root.resource { continue }
            guard let answer = answers[group.name] else { continue }
            var candidate: CompositionCandidate?
            var count = 0
            switch group.ask {
            case .skipped:
                continue
            case .predicate:
                if reader.predicate(answer) {
                    candidate = first
                    count = first.id == root.id ? 0 : 1
                }
            case .variants:
                let offered = Set([QuestionBuilder.omit] + group.members.map { "use:\($0.id)" })
                if let value = reader.choice(answer, offered: offered),
                    let chosen = group.members.first(where: { "use:\($0.id)" == value })
                {
                    candidate = chosen
                    count = chosen.id == root.id ? 0 : 1
                }
            case .counts(let max):
                let offered = Set((0...max).map(String.init))
                if let value = reader.choice(answer, offered: offered), let total = Int(value) {
                    candidate = first
                    count = total - (first.id == root.id ? 1 : 0)
                }
            }
            guard let candidate, count > 0 else { continue }
            for _ in 0..<count {
                if rootSlots.isEmpty || limits.maxDepth < 2 || selected.count >= budget {
                    limited = true
                    break
                }
                selected.append(candidate)
            }
        }
        return Selection(root: root, selected: selected, limited: limited)
    }

    /// The root's default slot, else its first slot (upstream `defaultSlot`).
    static func defaultSlot(of candidate: CompositionCandidate, catalog: Catalog) -> String? {
        let slots = catalog.component(named: candidate.element.type)?.slots ?? []
        return slots.contains("default") ? "default" : slots.first
    }

    /// The first preview: every element under the root's default slot, in catalog order.
    static func preview(
        _ selected: [CompositionCandidate], catalog: Catalog, state: JSONValue
    ) -> Spec {
        var spec = Spec(root: "node_0", elements: [:], state: state)
        for (index, candidate) in selected.enumerated() {
            spec.elements["node_\(index)"] = atomic(candidate.element)
        }
        if selected.count > 1, let slot = defaultSlot(of: selected[0], catalog: catalog) {
            for index in selected.indices.dropFirst() {
                attach(&spec, "node_\(index)", to: Attachment(id: "node_0", slot: slot))
            }
        }
        return spec
    }

    /// The candidate element with `children: []` and only `type`, `props`, `visible`, `on`.
    static func atomic(_ element: UIElement) -> UIElement {
        UIElement(
            type: element.type, props: element.props, children: [], visible: element.visible,
            on: element.on)
    }

    /// Upstream `attach`: append to `children` for the default slot, else to `slots[slot]`.
    static func attach(_ spec: inout Spec, _ id: String, to parent: Attachment) {
        guard var container = spec.elements[parent.id] else { return }
        if parent.slot == "default" {
            container.children = (container.children ?? []) + [id]
        } else {
            var slots = container.slots ?? [:]
            slots[parent.slot, default: []].append(id)
            container.slots = slots
        }
        spec.elements[parent.id] = container
    }

    /// Builds the layout on a copy of `preview`. Unanswered, refused or low-confidence
    /// parents use the root's default slot; such positions use catalog order. Equal
    /// positions keep catalog order.
    static func layout(
        preview: Spec, plan: LayoutPlan, answers: [String: DecisionAnswer],
        reader: inout AnswerReader, rootDefault: Attachment
    ) -> Spec {
        var next = preview
        for id in next.elements.keys {
            next.elements[id]?.children = []
            next.elements[id]?.slots = nil
        }
        let positionCount = plan.placements.count
        let offeredPositions = Set((1...max(positionCount, 1)).map(String.init))
        var arranged: [(id: String, parent: Attachment, position: Int, catalogIndex: Int)] = []
        for (catalogIndex, placement) in plan.placements.enumerated() {
            var parent = rootDefault
            if placement.parents.count == 1 {
                parent = placement.parents[0].attachment
            } else if let answer = answers["parent_\(placement.id)"] {
                let offered = Set(placement.parents.map(\.key))
                if let key = reader.choice(answer, offered: offered),
                    let match = placement.parents.first(where: { $0.key == key })
                {
                    parent = match.attachment
                }
            }
            var position = catalogIndex + 1
            if let answer = answers["order_\(placement.id)"],
                let value = reader.choice(answer, offered: offeredPositions),
                let chosen = Int(value)
            {
                position = chosen
            }
            arranged.append((placement.id, parent, position, catalogIndex))
        }
        arranged.sort { ($0.position, $0.catalogIndex) < ($1.position, $1.catalogIndex) }
        for item in arranged { attach(&next, item.id, to: item.parent) }
        return next
    }
}

/// Whole-tree checks before a spec is published (upstream `indexTree` plus
/// `Catalog.validate`).
enum CompositionTree {
    /// A short reason the tree is not acceptable, or `nil`.
    static func problem(_ spec: Spec, catalog: Catalog, maxDepth: Int) -> String? {
        if let reason = indexProblem(spec, catalog: catalog, maxDepth: maxDepth) { return reason }
        let report = catalog.validate(spec)
        if let error = report.errors.first { return "validation: \(error.code.rawValue)" }
        return nil
    }

    /// The element ids the validator reports errors for.
    static func offendingIDs(_ spec: Spec, catalog: Catalog) -> Set<String> {
        Set(catalog.validate(spec).errors.compactMap(\.elementKey))
    }

    static func warningCount(_ spec: Spec, catalog: Catalog) -> Int {
        catalog.validate(spec).warnings.count
    }

    /// Upstream `indexTree`: a tree with no cycle, shared child, dangling id or unreachable
    /// element, no deeper than `maxDepth` (root depth one), and every used slot declared by
    /// the parent's component.
    static func indexProblem(_ spec: Spec, catalog: Catalog, maxDepth: Int) -> String? {
        var seen: Set<String> = []
        var stack: [(id: String, depth: Int)] = [(spec.root, 1)]
        while let (id, depth) = stack.popLast() {
            guard let element = spec.elements[id] else { return "missing element" }
            guard seen.insert(id).inserted else { return "cycle or shared child" }
            guard depth <= maxDepth else { return "maxDepth exceeded" }
            if element.slots?["default"] != nil { return "default slot in slots" }
            let declared = catalog.component(named: element.type)?.slots ?? []
            var regions: [(slot: String, ids: [String])] = [("default", element.children ?? [])]
            for slot in (element.slots ?? [:]).keys.sorted() {
                regions.append((slot, element.slots?[slot] ?? []))
            }
            for region in regions where !region.ids.isEmpty {
                guard declared.contains(region.slot) else { return "undeclared slot" }
                for child in region.ids.reversed() { stack.append((child, depth + 1)) }
            }
        }
        guard seen.count == spec.elements.count else { return "unreachable elements (cycle)" }
        return nil
    }
}
