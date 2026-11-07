extension JSONValue {
    /// Upstream `flattenToPointers`: maps every leaf of a nested object to its JSON Pointer.
    /// Objects recurse (an empty object gives no entry); arrays, `null` and scalars are
    /// leaves. Recursion stops at depth 20, where the remaining object becomes a leaf.
    func flattenedToPointers() -> [String: JSONValue] {
        var result: [String: JSONValue] = [:]
        JSONValue.flatten(self, prefix: "", depth: 0, into: &result)
        return result
    }

    static let maxFlattenDepth = 20

    private static func flatten(
        _ value: JSONValue, prefix: String, depth: Int, into result: inout [String: JSONValue]
    ) {
        guard case .object(let members) = value else { return }
        for (key, member) in members {
            // Upstream builds the pointer by plain concatenation, without escaping.
            let pointer = "\(prefix)/\(key)"
            if depth < maxFlattenDepth, case .object = member {
                flatten(member, prefix: pointer, depth: depth + 1, into: &result)
            } else {
                result[pointer] = member
            }
        }
    }
}
