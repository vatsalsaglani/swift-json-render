/// The tree a renderer draws for one spec snapshot: one depth-first walk from the root over
/// `children`, then slots (slot names in code-point order).
///
/// Build it once per snapshot (the stream layer does), never in a view body. Cycles are not
/// descended; depth past `SpecLimits.maxDepth` is marked and not descended. Elements not
/// reachable from the root are not in the plan.
public struct RenderPlan: Sendable, Hashable {
    public struct Node: Sendable, Hashable {
        public let id: String
        public let type: String
        /// The root is depth 0.
        public let depth: Int
        /// The raw `children` ids, including dangling ones (see `RenderPlan.dangling`).
        public let childIDs: [String]
        /// The raw slot ids by slot name.
        public let slotIDs: [String: [String]]
        public let hasRepeat: Bool
    }

    /// The root id, or `nil` when the root element does not exist (yet).
    public let rootID: String?
    public let nodes: [String: Node]
    /// Node ids in visit order (depth-first, children before slots).
    public let order: [String]
    /// Ids referenced by a reachable node (or the root id) that have no element.
    public let dangling: Set<String>
    /// Each cycle once, as the ids on the path from the first repeated id, rotated so the
    /// smallest id is first.
    public let cycles: [[String]]
    /// Nodes deeper than `limits.maxDepth`; their children are not visited.
    public let truncatedAtDepth: Set<String>

    public init(spec: Spec, limits: SpecLimits = .default) {
        var builder = Builder(spec: spec, limits: limits)
        if spec.elements[spec.root] != nil {
            builder.visit(spec.root, depth: 0)
        } else if !spec.root.isEmpty {
            builder.dangling.insert(spec.root)
        }
        rootID = spec.elements[spec.root] != nil ? spec.root : nil
        nodes = builder.nodes
        order = builder.order
        dangling = builder.dangling
        cycles = builder.cycles
        truncatedAtDepth = builder.truncated
    }

    /// The visit uses recursion bounded by `limits.maxDepth` (at most 64 levels).
    private struct Builder {
        let spec: Spec
        let limits: SpecLimits
        var nodes: [String: Node] = [:]
        var order: [String] = []
        var dangling: Set<String> = []
        var cycles: [[String]] = []
        var cycleKeys: Set<[String]> = []
        var truncated: Set<String> = []
        var path: [String] = []
        var onPath: Set<String> = []

        init(spec: Spec, limits: SpecLimits) {
            self.spec = spec
            self.limits = limits
        }

        mutating func visit(_ id: String, depth: Int) {
            guard let element = spec.elements[id] else { return }
            let slots = element.slots ?? [:]
            nodes[id] = Node(
                id: id, type: element.type, depth: depth, childIDs: element.children ?? [],
                slotIDs: slots, hasRepeat: element.repeat != nil)
            order.append(id)
            if depth > limits.maxDepth {
                truncated.insert(id)
                return
            }
            path.append(id)
            onPath.insert(id)
            let targets =
                (element.children ?? []) + slots.keys.sorted().flatMap { slots[$0] ?? [] }
            for child in targets {
                if spec.elements[child] == nil {
                    dangling.insert(child)
                } else if onPath.contains(child) {
                    recordCycle(to: child)
                } else if nodes[child] == nil {
                    visit(child, depth: depth + 1)
                }
            }
            path.removeLast()
            onPath.remove(id)
        }

        private mutating func recordCycle(to id: String) {
            guard let start = path.firstIndex(of: id) else { return }
            let cycle = Array(path[start...])
            guard let smallest = cycle.indices.min(by: { cycle[$0] < cycle[$1] }) else { return }
            let rotated = Array(cycle[smallest...] + cycle[..<smallest])
            if cycleKeys.insert(rotated).inserted { cycles.append(rotated) }
        }
    }
}
