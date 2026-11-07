/// What a visibility condition reads: the state, and the repeat item and index when the
/// element is inside a `repeat` scope.
public struct VisibilityContext: Sendable {
    public var state: JSONValue
    public var repeatItem: JSONValue?
    public var repeatIndex: Int?

    public init(state: JSONValue, repeatItem: JSONValue? = nil, repeatIndex: Int? = nil) {
        self.state = state
        self.repeatItem = repeatItem
        self.repeatIndex = repeatIndex
    }
}

/// Upstream `evaluateVisibility`.
public enum VisibilityEvaluator {
    /// - A `nil` condition is visible.
    /// - `gt`, `gte`, `lt`, `lte` are `true` only when both sides are numbers.
    /// - `eq` / `neq` use `===` (`nil` is not `null`; arrays and objects compare by value).
    /// - `not` inverts the whole result of one condition.
    /// - `.invalid` is hidden.
    public static func evaluate(_ condition: VisibilityCondition?, in context: VisibilityContext)
        -> Bool
    {
        guard let condition else { return true }
        switch condition {
        case .always(let flag):
            return flag
        case .single(let single):
            return evaluate(single, in: context)
        case .all(let items), .and(let items):
            return items.allSatisfy { evaluate($0, in: context) }
        case .or(let items):
            return items.contains { evaluate($0, in: context) }
        case .invalid:
            return false
        }
    }

    static func evaluate(_ condition: SingleCondition, in context: VisibilityContext) -> Bool {
        let value = subjectValue(condition.subject, in: context)
        let result: Bool
        switch condition.comparison {
        case .eq(let operand)?:
            result = JSONValue.strictEquals(value, comparisonValue(operand, in: context))
        case .neq(let operand)?:
            result = !JSONValue.strictEquals(value, comparisonValue(operand, in: context))
        case .gt(let operand)?:
            result = compare(value, operand, in: context, by: >)
        case .gte(let operand)?:
            result = compare(value, operand, in: context, by: >=)
        case .lt(let operand)?:
            result = compare(value, operand, in: context, by: <)
        case .lte(let operand)?:
            result = compare(value, operand, in: context, by: <=)
        case nil:
            result = value?.isTruthy ?? false
        }
        return condition.not ? !result : result
    }

    private static func subjectValue(
        _ subject: SingleCondition.Subject, in context: VisibilityContext
    )
        -> JSONValue?
    {
        switch subject {
        case .index:
            return context.repeatIndex.map { .number(Double($0)) }
        case .item(let field):
            guard let item = context.repeatItem else { return nil }
            return field.isEmpty ? item : item.value(at: JSONPointer(lenient: field))
        case .state(let pointer):
            return context.state.value(at: pointer)
        }
    }

    /// Upstream `resolveComparisonValue`: a `{ "$state": "/p" }` object reads state; any
    /// other value is a literal.
    private static func comparisonValue(_ operand: JSONValue, in context: VisibilityContext)
        -> JSONValue?
    {
        if case .object(let members) = operand, case .string(let path)? = members["$state"] {
            return context.state.value(at: JSONPointer(lenient: path))
        }
        return operand
    }

    private static func compare(
        _ value: JSONValue?, _ operand: SingleCondition.Operand, in context: VisibilityContext,
        by predicate: (Double, Double) -> Bool
    ) -> Bool {
        guard case .number(let lhs)? = value else { return false }
        let rhs: JSONValue?
        switch operand {
        case .number(let number): rhs = .number(number)
        case .state(let pointer): rhs = context.state.value(at: pointer)
        case .other: return false
        }
        guard case .number(let right)? = rhs else { return false }
        return predicate(lhs, right)
    }
}
