import Testing

@testable import JSONRenderCore

@Suite("Catalog")
struct CatalogTests {
    @Test("Registration order is kept; a duplicate throws")
    func order() throws {
        var catalog = Catalog()
        for name in ["Zeta", "Alpha", "Mid"] {
            try catalog.register(ComponentDefinition(name: name))
        }
        #expect(catalog.componentNames == ["Zeta", "Alpha", "Mid"])
        #expect(throws: CatalogError.duplicateComponent("Alpha")) {
            try catalog.register(ComponentDefinition(name: "Alpha"))
        }
        #expect(catalog.component(named: "Mid")?.name == "Mid")
    }

    @Test("The init keeps existing calls compiling and ignores a later duplicate")
    func initDefaults() {
        let catalog = Catalog(components: [
            ComponentDefinition(name: "A", description: "first"),
            ComponentDefinition(name: "A", description: "second"),
        ])
        #expect(catalog.components.map(\.description) == ["first"])
        #expect(
            Catalog(actions: ["b": ActionDefinition(), "a": ActionDefinition()]).actionOrder == [
                "a", "b",
            ])
        #expect(
            Catalog().builtInActions.map(\.name) == [
                "setState", "pushState", "removeState", "validateForm",
            ])
        #expect(Catalog().defaultRules.count == 12)
    }

    @Test("Merging unions entries and throws on any conflict")
    func merging() throws {
        var left = Catalog(components: [ComponentDefinition(name: "A")])
        left.action("save")
        left.function("f") { _ in nil }
        var right = Catalog(components: [ComponentDefinition(name: "B")])
        right.action("load")
        right.function("g", description: "G") { _ in nil }
        right.rule("r") { _, _ in [] }
        let merged = try left.merging(right)
        #expect(merged.componentNames == ["A", "B"])
        #expect(merged.actionOrder == ["save", "load"])
        #expect(merged.functionOrder == ["f", "g"])
        #expect(merged.functionDescriptions["g"] == "G")
        #expect(merged.ruleOrder == ["r"])
        #expect(throws: CatalogError.duplicateComponent("A")) { try merged.merging(left) }
        var clash = Catalog()
        clash.action("save")
        #expect(throws: CatalogError.duplicateAction("save")) { try left.merging(clash) }
        var functionClash = Catalog()
        functionClash.function("f") { _ in nil }
        #expect(throws: CatalogError.duplicateFunction("f")) { try left.merging(functionClash) }
    }

    @Test("replaceDefinition keeps the position; unknown names throw")
    func replace() throws {
        var catalog = Catalog(components: [
            ComponentDefinition(name: "A"), ComponentDefinition(name: "B"),
        ])
        try catalog.replaceDefinition(ComponentDefinition(name: "A", description: "new"))
        #expect(catalog.components.first?.description == "new")
        #expect(throws: CatalogError.unknownComponent("Z")) {
            try catalog.replaceDefinition(ComponentDefinition(name: "Z"))
        }
    }

    @Test("Secret props are recorded on the definition")
    func secretProps() {
        let definition = ComponentDefinition(name: "Input", secretProps: ["value"])
        #expect(definition.secretProps == ["value"])
    }
}

@Suite("PropSchema tools")
struct PropSchemaToolTests {
    @Test("formatted() matches upstream formatZodType")
    func formatted() {
        #expect(PropSchema.string.formatted() == "string")
        #expect(PropSchema.any.formatted() == "unknown")
        #expect(PropSchema.enum(["a", "b"]).formatted() == "\"a\" | \"b\"")
        #expect(PropSchema.literal("x").formatted() == "\"x\"")
        #expect(PropSchema.array(.array(.string)).formatted() == "Array<Array<string>>")
        #expect(PropSchema.record(.any).formatted() == "Record<string, unknown>")
        #expect(PropSchema.union([.string, .number]).formatted() == "string | number")
        #expect(
            PropSchema.object([
                .init(name: "title", schema: .string),
                .init(name: "subtitle", schema: PropSchema.string.nullable()),
                .init(name: "n", schema: PropSchema.number.optional()),
            ]).formatted() == "{ title: string, subtitle?: string, n?: number }")
        #expect(PropSchema.object([]).formatted() == "{  }")
    }

    @Test("jsonSchema strict and loose")
    func jsonSchema() throws {
        let schema = PropSchema.object([
            .init(name: "a", schema: .string),
            .init(name: "b", schema: PropSchema.number.optional()),
        ])
        #expect(
            schema.jsonSchemaText(strict: true)
                == #"{"type":"object","properties":{"a":{"type":"string"},"b":{"anyOf":[{"type":"number"},{"type":"null"}]}},"required":["a","b"],"additionalProperties":false}"#
        )
        #expect(
            schema.jsonSchemaText(strict: false)
                == #"{"type":"object","properties":{"a":{"type":"string"},"b":{"type":"number"}},"required":["a"],"additionalProperties":false}"#
        )
        #expect(
            PropSchema.record(.string).jsonSchema(strict: false) == [
                "type": "object", "additionalProperties": ["type": "string"],
            ])
        #expect(PropSchema.any.jsonSchema(strict: false) == [:])
        #expect(
            PropSchema.object([]).jsonSchemaText(strict: true)
                == #"{"type":"object","properties":{},"additionalProperties":false}"#)
    }

    @Test("exampleValue uses required fields only")
    func example() {
        let schema = PropSchema.object([
            .init(name: "label", schema: .string),
            .init(name: "count", schema: .number),
            .init(name: "on", schema: .boolean),
            .init(name: "kind", schema: .enum(["x", "y"])),
            .init(name: "items", schema: .array(.string)),
            .init(name: "skip", schema: PropSchema.string.nullable()),
            .init(name: "map", schema: .record(.any)),
        ])
        #expect(
            schema.exampleValue()
                == [
                    "label": "example", "count": 0, "on": true, "kind": "x", "items": [],
                    "map": "...",
                ])
        #expect(schema.firstRequiredStringField() == "label")
    }

    @Test("validate() reports paths, never values")
    func validate() {
        let schema = PropSchema.object([
            .init(name: "rows", schema: .array(.object([.init(name: "id", schema: .number)])))
        ])
        let issues = schema.validate(["rows": [["id": 1], ["id": "x"]]])
        #expect(issues == [PropIssue(path: "rows.1.id", message: "Expected number.")])
        #expect(schema.validate(["rows": [["id": ["$item": "n"]]]]).isEmpty)
    }

    @Test("Deep values stop at the depth cap without crashing")
    func deep() {
        var schema = PropSchema.string
        var value: JSONValue = "x"
        for _ in 0..<200 {
            schema = .array(schema)
            value = [value]
        }
        #expect(schema.validate(value).isEmpty)
    }
}

@Suite("User prompt and edit modes")
struct UserPromptTests {
    @Test("Fresh generation with state")
    func fresh() {
        let text = UserPrompt.build(prompt: "make a todo app", state: ["b": 1, "a": [true]])
        #expect(
            text
                == "make a todo app\n\nAVAILABLE STATE:\n{\n  \"a\": [\n    true\n  ],\n  \"b\": 1\n}\n\nRemember: Output /root first, then interleave /elements and /state patches so the UI fills in progressively as it streams. Output each state patch right after the elements that use it, one per array item."
        )
    }

    @Test("Edit prompt with the current spec; diff mode numbers lines")
    func edit() {
        let spec = Spec(root: "m", elements: ["m": UIElement(type: "Card", children: [])])
        let patch = UserPrompt.build(prompt: "rename", currentSpec: spec)
        #expect(
            patch.hasPrefix(
                "CURRENT UI STATE (already loaded, DO NOT recreate existing elements):\n```\n{\n  \"root\": \"m\","
            ))
        #expect(
            patch.hasSuffix(
                "USER REQUEST: rename\n\nOutput ONLY the JSON Patch lines needed for the change."))
        let diff = UserPrompt.build(prompt: "x", currentSpec: spec, editModes: [.patch, .diff])
        #expect(diff.contains(" 1| {\n 2|   \"root\": \"m\","))
        #expect(
            diff.hasSuffix(
                "Choose the best edit strategy and output using one of: JSON Patch lines, ```diff fence"
            ))
    }

    @Test("Truncation never splits a character")
    func truncate() {
        #expect(UserPrompt.build(prompt: "a😀b", maxPromptLength: 2).hasPrefix("a\n"))
    }
}
