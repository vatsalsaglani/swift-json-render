/// A registered `$computed` function. It receives the resolved `args` (`nil` = undefined).
public typealias ComputedFunction = @Sendable (_ args: [String: JSONValue?]) -> JSONValue?

/// Everything a prop expression can read (upstream `PropResolutionContext`).
public struct PropResolutionContext: Sendable {
    public var state: JSONValue
    /// The current repeat item, inside a `repeat` scope.
    public var repeatItem: JSONValue?
    /// The current repeat index, inside a `repeat` scope.
    public var repeatIndex: Int?
    /// The absolute state path of the current repeat item (for example `/todos/0`).
    public var repeatBasePath: JSONPointer?
    /// Functions for `$computed`. Empty means none are registered.
    public var functions: [String: ComputedFunction]
    /// Custom directives.
    public var directives: DirectiveRegistry

    public init(
        state: JSONValue, repeatItem: JSONValue? = nil, repeatIndex: Int? = nil,
        repeatBasePath: JSONPointer? = nil, functions: [String: ComputedFunction] = [:],
        directives: DirectiveRegistry = DirectiveRegistry()
    ) {
        self.state = state
        self.repeatItem = repeatItem
        self.repeatIndex = repeatIndex
        self.repeatBasePath = repeatBasePath
        self.functions = functions
        self.directives = directives
    }

    /// A context for an element inside `scope` (or outside any repeat when `scope` is `nil`).
    public init(
        state: JSONValue, scope: RepeatScope?, functions: [String: ComputedFunction] = [:],
        directives: DirectiveRegistry = DirectiveRegistry()
    ) {
        self.init(
            state: state, repeatItem: scope?.item, repeatIndex: scope?.index,
            repeatBasePath: scope?.basePath, functions: functions, directives: directives)
    }

    /// The part that visibility conditions read.
    public var visibility: VisibilityContext {
        VisibilityContext(state: state, repeatItem: repeatItem, repeatIndex: repeatIndex)
    }
}

/// A problem met while resolving. Warnings carry names and paths only, never values.
public enum ResolutionWarning: Sendable, Hashable {
    /// `$computed` named a function that is not registered. The value is `nil`.
    case unknownComputed(String)
    /// `$bindItem` (or an action `$item` param) outside a repeat scope. The value is `nil`.
    case bindItemOutsideScope(String)
    /// A parsed `.directive` names a directive that is not in the context's registry.
    case unknownDirective(String)
    /// An object holds two directive keys. The value is `nil` (upstream throws).
    case ambiguousDirective(String, String)
}

/// Resolves prop expressions against one context (upstream `resolvePropValue`,
/// `resolveElementProps`, `resolveBindings`, `resolveActionParam`).
///
/// Use one resolver per element render. It collects warnings, each at most once, and at
/// most `maxWarnings` of them, so an unknown `$computed` name in a 1,000-row repeat gives
/// one warning. To de-duplicate across renders, feed the warnings to a `ResolutionJournal`.
public struct PropResolver: Sendable {
    public static let maxWarnings = 100

    public var context: PropResolutionContext
    public private(set) var warnings: [ResolutionWarning] = []
    private var recorded: Set<ResolutionWarning> = []

    public init(context: PropResolutionContext) {
        self.context = context
    }

    /// Resolves an expression. `nil` is upstream `undefined`.
    public mutating func resolve(_ expression: PropExpression) -> JSONValue? {
        switch expression {
        case .literal(let value):
            return value
        case .state(let pointer), .bindState(let pointer):
            return context.state.value(at: pointer)
        case .item(let field):
            guard let item = context.repeatItem else { return nil }
            return field.isEmpty ? item : item.value(at: JSONPointer(lenient: field))
        case .bindItem(let field):
            guard let path = bindItemPath(field) else { return nil }
            return context.state.value(at: path)
        case .index:
            return context.repeatIndex.map { .number(Double($0)) }
        case .cond(let condition, let thenExpression, let elseExpression):
            let visible = VisibilityEvaluator.evaluate(condition, in: context.visibility)
            return resolve(visible ? thenExpression : elseExpression)
        case .computed(let name, let args):
            guard let function = context.functions[name] else {
                record(.unknownComputed(name))
                return nil
            }
            var resolvedArgs: [String: JSONValue?] = [:]
            for (key, arg) in args {
                resolvedArgs[key] = .some(resolve(arg))
            }
            return function(resolvedArgs)
        case .template(let template):
            return .string(
                Template.render(template, state: context.state, repeatItem: context.repeatItem))
        case .directive(let name, let raw):
            guard let definition = context.directives[name] else {
                record(.unknownDirective(name))
                return nil
            }
            return definition.resolve(raw, &self)
        case .array(let items):
            return .array(items.map { resolve($0) ?? .null })
        case .object(let members):
            var resolved: [String: JSONValue] = [:]
            for (key, member) in members {
                if let value = resolve(member) { resolved[key] = value }
            }
            return .object(resolved)
        }
    }

    /// Parses `value` with the context's directives, then resolves it. Directives call this
    /// on their operands.
    public mutating func resolveValue(_ value: JSONValue) -> JSONValue? {
        do {
            let expression = try PropExpression.parse(
                value, orderedDirectives: context.directives.orderedNames)
            return resolve(expression)
        } catch {
            switch error {
            case .ambiguousDirective(let first, let second):
                record(.ambiguousDirective(first, second))
            }
            return nil
        }
    }

    /// Upstream `resolveElementProps`. Every key stays; `nil` is undefined.
    public mutating func resolveProps(_ props: [String: JSONValue]) -> [String: JSONValue?] {
        var resolved: [String: JSONValue?] = [:]
        for (key, value) in props {
            resolved[key] = .some(resolveValue(value))
        }
        return resolved
    }

    /// Upstream `resolveBindings`: prop name to absolute state path for top-level
    /// `$bindState` and `$bindItem` props. `$bindItem` outside a repeat scope is omitted
    /// with a warning. Empty when nothing binds (upstream `undefined`).
    public mutating func bindings(in props: [String: JSONValue]) -> [String: JSONPointer] {
        var bindings: [String: JSONPointer] = [:]
        for (key, value) in props {
            guard case .object(let members) = value else { continue }
            if case .string(let path)? = members["$bindState"] {
                bindings[key] = JSONPointer(lenient: path)
            } else if case .string(let field)? = members["$bindItem"] {
                if let path = bindItemPath(field) { bindings[key] = path }
            }
        }
        return bindings
    }

    /// Upstream `resolveActionParam`: `{ "$item": "field" }` gives the absolute state path
    /// as a string (so it can feed `setState`); `{ "$index": true }` gives the index; other
    /// values resolve normally.
    public mutating func resolveActionParam(_ value: JSONValue) -> JSONValue? {
        if case .object(let members) = value {
            if case .string(let field)? = members["$item"] {
                return bindItemPath(field).map { .string($0.description) }
            }
            if members["$index"] == .bool(true) {
                return context.repeatIndex.map { .number(Double($0)) }
            }
        }
        return resolveValue(value)
    }

    /// Upstream `resolveBindItemPath`: `""` is the base path, `"field"` is `base/field`.
    func itemPath(for field: String) -> JSONPointer? {
        guard let base = context.repeatBasePath else {
            return nil
        }
        return field.isEmpty ? base : base.appending(relative: field)
    }

    private mutating func bindItemPath(_ field: String) -> JSONPointer? {
        let path = itemPath(for: field)
        if path == nil { record(.bindItemOutsideScope(field)) }
        return path
    }

    private mutating func record(_ warning: ResolutionWarning) {
        guard warnings.count < PropResolver.maxWarnings, !recorded.contains(warning) else { return }
        recorded.insert(warning)
        warnings.append(warning)
    }
}

/// A bounded, de-duplicated list of resolution warnings across renders. The owner (for
/// example a view model) keeps one per spec and records each resolver's warnings into it.
public struct ResolutionJournal: Sendable, Hashable {
    public static let capacity = 100

    public private(set) var entries: [ResolutionWarning] = []
    /// Recordings of new warnings that were not kept because the journal was full.
    public private(set) var droppedCount = 0
    private var seen: Set<ResolutionWarning> = []

    public init() {}

    public mutating func record(_ warnings: [ResolutionWarning]) {
        for warning in warnings where !seen.contains(warning) {
            if entries.count < ResolutionJournal.capacity {
                seen.insert(warning)
                entries.append(warning)
            } else {
                droppedCount += 1
            }
        }
    }
}
