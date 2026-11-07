import Foundation
import Testing

@testable import JSONRenderCore

/// `upstream/prompt/*.txt`: `catalog.prompt()` byte for byte.
@Suite("Prompt parity (upstream/prompt)")
struct PromptParityTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let file: String
        let catalog: String
        let inline: Bool
        var testDescription: String { file }
    }

    static let cases = [
        Case(file: "shadcn-standalone.txt", catalog: "shadcn", inline: false),
        Case(file: "shadcn-inline.txt", catalog: "shadcn", inline: true),
        Case(file: "minimal-two-components.txt", catalog: "minimal-two-components", inline: false),
    ]

    @Test("Matches the upstream prompt", arguments: cases)
    func matches(_ fixture: Case) throws {
        let expected = String(
            decoding: try ParityFixtures.data("prompt/\(fixture.file)"), as: UTF8.self)
        let catalog = try ShadcnCatalogFixture.catalog(fixture.catalog)
        let actual = catalog.prompt(
            PromptOptions(mode: fixture.inline ? .inline : .standalone, includeExtensions: false))
        #expect(
            TextDiff.differingLines(expected, actual) == 0,
            "\(TextDiff.describe(expected: expected, actual: actual))")
        #expect(actual == expected)
    }

    @Test("The shadcn catalog has 36 components in fixture order")
    func componentCount() throws {
        let catalog = try ShadcnCatalogFixture.catalog("shadcn")
        #expect(catalog.components.count == 36)
        #expect(catalog.componentNames.prefix(3) == ["Card", "Stack", "Grid"])
    }

    @Test("Default options list the extension actions after the built-ins")
    func extensions() throws {
        let catalog = try ShadcnCatalogFixture.catalog("minimal-two-components")
        let lines = catalog.prompt().components(separatedBy: "\n")
        guard let validate = lines.firstIndex(where: { $0.hasPrefix("- validateForm:") }) else {
            Issue.record("No validateForm line")
            return
        }
        #expect(lines[validate + 1].hasPrefix("- toggleState: "))
        #expect(lines[validate + 2].hasPrefix("- incrementState: "))
        #expect(lines[validate + 1].hasSuffix("[built-in]"))
        let upstream = catalog.prompt(PromptOptions(includeExtensions: false))
        #expect(!upstream.contains("toggleState"))
    }

    @Test("Computed functions are listed with descriptions, in registration order")
    func functions() throws {
        var catalog = try ShadcnCatalogFixture.catalog("minimal-two-components")
        #expect(!catalog.prompt().contains("5. Computed:"))
        catalog.function("sum", description: "Adds the values") { _ in .number(0) }
        catalog.function("count") { _ in .number(0) }
        let text = catalog.prompt()
        #expect(text.contains("   Available functions:\n   - sum — Adds the values\n   - count\n"))
    }

    @Test("Custom actions, directives, validators, edit modes and custom rules")
    func optionalSections() throws {
        var catalog = try ShadcnCatalogFixture.catalog("minimal-two-components")
        catalog.action("save", description: "Save the form")
        catalog.action("reset")
        catalog.directive(
            try DirectiveDefinition(name: "$upper", description: "Upper-case", schema: .string) {
                _, _ in nil
            })
        let text = catalog.prompt(
            PromptOptions(customRules: ["Be brief"], editModes: [.patch, .merge]))
        #expect(text.contains("- save: Save the form\n- reset\n"))
        #expect(text.contains("CUSTOM DYNAMIC VALUES:\n\n- $upper (Upper-case): string\n"))
        #expect(text.contains("EDITING EXISTING SPECS:\n\nChoose the best edit strategy"))
        #expect(text.hasSuffix(". Be brief"))
    }

    @Test("The VALIDATION section appears only with a checks prop")
    func validationSection() throws {
        let minimal = try ShadcnCatalogFixture.catalog("minimal-two-components")
        #expect(!minimal.prompt().contains("VALIDATION:"))
        let shadcn = try ShadcnCatalogFixture.catalog("shadcn")
        let text = shadcn.prompt()
        #expect(text.contains(BuiltInValidation.promptLines.joined(separator: "\n")))
    }
}

/// `upstream/schema/*.json`: `catalog.jsonSchema({ strict })`.
@Suite("JSON Schema parity (upstream/schema)")
struct JSONSchemaParityTests {
    @Test(
        "Matches the upstream schema",
        arguments: [
            ("shadcn.strict.json", "shadcn", true), ("shadcn.loose.json", "shadcn", false),
            ("minimal-two-components.strict.json", "minimal-two-components", true),
        ])
    func matches(_ file: String, _ catalogName: String, _ strict: Bool) throws {
        let expected = try ParityFixtures.json("schema/\(file)")
        let catalog = try ShadcnCatalogFixture.catalog(catalogName)
        #expect(try catalog.jsonSchema(strict: strict).canonicalText() == expected.canonicalText())
    }

    @Test("The ordered text equals the upstream bytes after re-serialisation")
    func orderedText() throws {
        let catalog = try ShadcnCatalogFixture.catalog("shadcn")
        for (file, strict) in [("shadcn.strict.json", true), ("shadcn.loose.json", false)] {
            let upstream = try OrderedNode.parse(ParityFixtures.data("schema/\(file)"))
            #expect(catalog.jsonSchemaText(strict: strict) == compact(upstream))
        }
        #expect(catalog.jsonSchemaText(strict: true).utf8.count == 205)
        #expect(catalog.jsonSchemaText(strict: false).utf8.count == 863)
    }

    /// `JSON.stringify` of the parsed upstream file (members in file order).
    private func compact(_ node: OrderedNode) -> String {
        switch node {
        case .null: "null"
        case .bool(let flag): flag ? "true" : "false"
        case .number(let number): JSONValue.number(number).jsString
        case .string(let text): OrderedJSON.quote(text)
        case .array(let items): "[" + items.map(compact).joined(separator: ",") + "]"
        case .object(let members):
            "{"
                + members.map { OrderedJSON.quote($0.0) + ":" + compact($0.1) }.joined(
                    separator: ",")
                + "}"
        }
    }

    @Test("One component: type is a literal and props is its schema")
    func singleComponent() throws {
        let catalog = Catalog(components: [
            ComponentDefinition(
                name: "Text", props: .object([.init(name: "text", schema: .string)]))
        ])
        let element = catalog.jsonSchema(strict: false)["properties"]?["elements"]?[
            "additionalProperties"]
        #expect(element?["properties"]?["type"] == ["const": "Text"])
        #expect(element?["properties"]?["props"]?["required"] == ["text"])
    }
}
