/// Upstream `findFormValue` (`types.ts`): finds a form field value in action params or
/// state, for action handlers that receive form data.
public enum FormValues {
    /// Looks for `fieldName` in this order:
    /// 1. `params[fieldName]` when it is not undefined;
    /// 2. the first params key that ends with `".fieldName"` (its value, also when undefined);
    /// 3. the first state key equal to `fieldName` or ending with `".fieldName"`;
    /// 4. the value at `fieldName` read as a (lenient) JSON Pointer in `state`.
    ///
    /// Documented deviation: upstream scans keys in insertion order. Swift dictionaries have
    /// no order, so keys are scanned in code-point order. "First" means first in that order.
    public static func find(
        _ fieldName: String, params: [String: JSONValue?]? = nil, state: JSONValue? = nil
    ) -> JSONValue? {
        if let params {
            if let direct = params[fieldName], let value = direct { return value }
            let suffix = "." + fieldName
            if let key = params.keys.sorted().first(where: { $0.hasSuffix(suffix) }) {
                return params[key] ?? nil
            }
        }
        guard let state else { return nil }
        if case .object(let members) = state {
            let suffix = "." + fieldName
            if let key = members.keys.sorted().first(where: {
                $0 == fieldName || $0.hasSuffix(suffix)
            }) {
                return members[key]
            }
        }
        let pointer = JSONPointer(lenient: fieldName)
        guard !pointer.containsForbiddenToken else { return nil }
        return state.value(at: pointer)
    }
}
