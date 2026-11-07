import Testing

@testable import JSONRenderCore

/// `upstream/expressions/*.json`: `resolvePropValue`, `resolveElementProps` and
/// `resolveBindings`.
@Suite("Expression parity (upstream/expressions)")
struct ExpressionParityTests {
    @Test("Replays the case", arguments: ParityFixtures.cases("expressions"))
    func replay(_ fixture: FixtureCase) throws {
        var resolver = PropResolver(context: try ParityFixtures.context(fixture))
        switch fixture.kind {
        case "value":
            let input = fixture.value("input")
            let actual = input.flatMap { resolver.resolveValue($0) }
            #expect(actual == fixture.value("expected"))
        case "props":
            let input = fixture.value("input")?.objectValue ?? [:]
            let resolved = resolver.resolveProps(input)
            #expect(Set(resolved.keys) == Set(input.keys))
            let defined = resolved.compactMapValues { $0 }
            #expect(JSONValue.object(defined) == fixture.value("expected"))
        case "bindings":
            let input = fixture.value("input")?.objectValue ?? [:]
            let bindings = resolver.bindings(in: input)
            let expected = fixture.value("expectedBindings")?.objectValue ?? [:]
            #expect(bindings.mapValues { JSONValue.string($0.description) } == expected)
        default:
            Issue.record("Unknown kind \(fixture.kind ?? "nil")")
        }
    }
}

@Suite("Directives")
struct DirectiveTests {
    @Test("A built-in key cannot be a directive name")
    func builtInCollision() {
        for name in PropExpression.builtInKeys {
            #expect(throws: DirectiveError.conflictsWithBuiltIn(name)) {
                try DirectiveDefinition(name: name, schema: .any) { _, _ in nil }
            }
        }
        #expect(throws: DirectiveError.missingDollarPrefix("format")) {
            try DirectiveDefinition(name: "format", schema: .any) { _, _ in nil }
        }
    }

    @Test("Two directive keys in one object are ambiguous")
    func ambiguity() throws {
        #expect(throws: PropExpressionError.ambiguousDirective("$a", "$b")) {
            try PropExpression.parse(["$a": 1, "$b": 2], directiveNames: ["$b", "$a"])
        }
        let registry = try ParityFixtures.directives(["$double", "$upper"])
        var resolver = PropResolver(
            context: PropResolutionContext(state: [:], directives: registry))
        #expect(resolver.resolveValue(["$double": 1, "$upper": "x"]) == nil)
        #expect(resolver.warnings == [.ambiguousDirective("$double", "$upper")])
    }

    @Test("Built-ins win over a directive key in the same object")
    func builtInsWin() throws {
        let registry = try ParityFixtures.directives(["$double"])
        var resolver = PropResolver(
            context: PropResolutionContext(state: ["n": 4], directives: registry))
        #expect(resolver.resolveValue(["$state": "/n", "$double": 10]) == 4)
    }

    @Test("A directive composes with $state, $cond and nested directives")
    func composes() throws {
        let registry = try ParityFixtures.directives(["$double", "$upper"])
        var resolver = PropResolver(
            context: PropResolutionContext(
                state: ["n": 3, "on": true, "name": "ada"], directives: registry))
        #expect(resolver.resolveValue(["$double": ["$state": "/n"]]) == 6)
        #expect(
            resolver.resolveValue(["$double": ["$cond": ["$state": "/on"], "$then": 5, "$else": 0]])
                == 10)
        #expect(
            resolver.resolveValue(["label": ["$upper": ["$template": "hi ${/name}"]]]) == [
                "label": "HI ADA"
            ])
        #expect(registry.orderedNames == ["$double", "$upper"])
    }

    @Test("A parsed directive missing from the registry resolves to nil with a warning")
    func unknownDirective() {
        var resolver = PropResolver(context: PropResolutionContext(state: [:]))
        #expect(resolver.resolve(.directive(name: "$gone", raw: ["$gone": 1])) == nil)
        #expect(resolver.warnings == [.unknownDirective("$gone")])
    }
}

@Suite("Computed functions")
struct ComputedTests {
    @Test("Unknown name: nil and one warning across 1,000 resolves")
    func unknownOnce() {
        var resolver = PropResolver(context: PropResolutionContext(state: [:]))
        for _ in 0..<1_000 {
            #expect(resolver.resolveValue(["$computed": "missing"]) == nil)
        }
        #expect(resolver.warnings == [.unknownComputed("missing")])

        var journal = ResolutionJournal()
        for _ in 0..<1_000 {
            var perRender = PropResolver(context: PropResolutionContext(state: [:]))
            _ = perRender.resolveValue(["$computed": "missing"])
            journal.record(perRender.warnings)
        }
        #expect(journal.entries == [.unknownComputed("missing")])
    }

    @Test("Warnings are bounded to 100 distinct entries")
    func bounded() {
        var resolver = PropResolver(context: PropResolutionContext(state: [:]))
        for index in 0..<250 {
            _ = resolver.resolveValue(["$computed": .string("f\(index)")])
        }
        #expect(resolver.warnings.count == PropResolver.maxWarnings)
        var journal = ResolutionJournal()
        journal.record(resolver.warnings)
        journal.record([.unknownComputed("extra")])
        #expect(journal.entries.count == ResolutionJournal.capacity)
        #expect(journal.droppedCount == 1)
    }

    @Test("Args resolve before the call; undefined args are passed as nil")
    func args() {
        let probe: ComputedFunction = { args in
            .string(
                args.keys.sorted().map { "\($0)=\(args[$0]!.map(\.jsString) ?? "undefined")" }
                    .joined(separator: ","))
        }
        var resolver = PropResolver(
            context: PropResolutionContext(
                state: ["a": 1], repeatIndex: 2, functions: ["probe": probe]))
        #expect(
            resolver.resolveValue([
                "$computed": "probe",
                "args": ["x": ["$state": "/a"], "y": ["$state": "/none"], "z": ["$index": true]],
            ])
                == "x=1,y=undefined,z=2")
    }

    @Test("$bindItem outside a repeat warns once and binds nothing")
    func bindItemOutsideScope() {
        var resolver = PropResolver(context: PropResolutionContext(state: [:]))
        #expect(resolver.bindings(in: ["v": ["$bindItem": "done"]]).isEmpty)
        #expect(resolver.resolveValue(["$bindItem": "done"]) == nil)
        #expect(resolver.warnings == [.bindItemOutsideScope("done")])
    }

    @Test("Template edge cases follow the upstream regular expression")
    func templates() {
        var resolver = PropResolver(
            context: PropResolutionContext(state: ["a": "A", "n": .null, "list": [1, 2]]))
        #expect(resolver.resolveValue(["$template": "${}"]) == "${}")
        #expect(resolver.resolveValue(["$template": "x ${/a"]) == "x ${/a")
        #expect(resolver.resolveValue(["$template": "$${/a}}"]) == "$A}")
        #expect(resolver.resolveValue(["$template": "[${/n}]"]) == "[]")
        #expect(resolver.resolveValue(["$template": "${/list}"]) == "1,2")
    }
}
