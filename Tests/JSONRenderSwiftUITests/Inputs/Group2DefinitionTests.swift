import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderStandardCatalog

/// Definition shape, registration and prompt parity of jr-3b's 18 components.
@Suite struct Group2DefinitionTests {
    struct Shape: Sendable, CustomTestStringConvertible {
        let definition: ComponentDefinition
        let props: [String]
        let required: [String]
        let slots: [String]
        let events: [String]
        var testDescription: String { definition.name }
    }

    static let group2 = [
        "Image", "Avatar", "Carousel", "Table", "Progress", "Spinner", "Button", "Link", "Input",
        "Textarea", "Select", "Checkbox", "Radio", "Switch", "Slider", "Toggle", "ToggleGroup",
        "ButtonGroup",
    ]

    static let field = ["checks", "validateOn"]

    static let shapes: [Shape] = [
        Shape(
            definition: JRImage.definition, props: ["src", "alt", "width", "height", "fit"],
            required: ["alt"], slots: ["error", "loading"], events: []),
        Shape(
            definition: JRAvatar.definition, props: ["src", "name", "size"], required: ["name"],
            slots: [], events: []),
        Shape(
            definition: JRCarousel.catalogDefinition, props: ["items"], required: ["items"],
            slots: ["default"], events: []),
        Shape(
            definition: JRTable.catalogDefinition,
            props: ["columns", "rows", "caption", "sortable"], required: ["columns", "rows"],
            slots: ["default", "empty", "loading"], events: []),
        Shape(
            definition: JRProgress.definition, props: ["value", "max", "label"],
            required: ["value"], slots: [], events: []),
        Shape(
            definition: JRSpinner.definition, props: ["size", "label"], required: [], slots: [],
            events: []),
        Shape(
            definition: JRButton.definition,
            props: ["label", "variant", "disabled", "size", "icon"], required: ["label"],
            slots: [], events: ["press"]),
        Shape(
            definition: JRLink.definition, props: ["label", "href"], required: ["label", "href"],
            slots: [], events: ["press"]),
        Shape(
            definition: JRInput.catalogDefinition,
            props: ["label", "name", "type", "placeholder", "value"] + field,
            required: ["label", "name"], slots: [], events: ["submit", "focus", "blur"]),
        Shape(
            definition: JRTextarea.catalogDefinition,
            props: ["label", "name", "placeholder", "rows", "value"] + field,
            required: ["label", "name"], slots: [], events: []),
        Shape(
            definition: JRSelect.catalogDefinition,
            props: ["label", "name", "options", "placeholder", "value"] + field,
            required: ["label", "name", "options"], slots: [], events: ["change"]),
        Shape(
            definition: JRCheckbox.catalogDefinition,
            props: ["label", "name", "checked"] + field, required: ["label", "name"], slots: [],
            events: ["change"]),
        Shape(
            definition: JRRadio.catalogDefinition,
            props: ["label", "name", "options", "value"] + field,
            required: ["label", "name", "options"], slots: [], events: ["change"]),
        Shape(
            definition: JRSwitch.catalogDefinition, props: ["label", "name", "checked"] + field,
            required: ["label", "name"], slots: [], events: ["change"]),
        Shape(
            definition: JRSlider.definition, props: ["label", "min", "max", "step", "value"],
            required: [], slots: [], events: ["change"]),
        Shape(
            definition: JRToggle.definition, props: ["label", "pressed", "variant"],
            required: ["label"], slots: [], events: ["change"]),
        Shape(
            definition: JRToggleGroup.catalogDefinition, props: ["items", "type", "value"],
            required: ["items"], slots: [], events: ["change"]),
        Shape(
            definition: JRButtonGroup.catalogDefinition, props: ["buttons", "selected"],
            required: ["buttons"], slots: [], events: ["change"]),
    ]

    @Test(arguments: Group2DefinitionTests.shapes)
    func definitionShape(_ shape: Shape) throws {
        guard case .object(let fields) = shape.definition.props.kind else {
            Issue.record("props is not an object")
            return
        }
        #expect(fields.map(\.name) == shape.props)
        // Required = neither optional nor nullable (upstream nullable reads as "?").
        #expect(
            fields.filter { !$0.schema.isOptional && !$0.schema.isNullable }.map(\.name)
                == shape.required)
        #expect(!shape.definition.description.isEmpty)
        #expect(shape.definition.slots == shape.slots)
        #expect(shape.definition.events == shape.events)
    }

    @Test func group2IsRegisteredAfterGroup1InTableOrder() throws {
        let names = try Catalog.standard.componentNames
        #expect(names.count == 36)
        #expect(Array(names.suffix(18)) == Self.group2)
        #expect(StandardEntries.components.suffix(18).map(\.name) == Self.group2)
    }

    @Test(arguments: Group2DefinitionTests.group2)
    func everyComponentKeepsItsRenderer(_ name: String) throws {
        let catalog = try Catalog.standard
        #expect(catalog.viewFactory(for: name) != nil)
        #expect(
            catalog.component(named: name) == StandardEntries.components.first { $0.name == name })
    }

    @Test(arguments: Group2DefinitionTests.group2)
    func promptLineMatchesUpstream(_ name: String) throws {
        let catalog = try Catalog.standard
        let definition = try #require(catalog.component(named: name))
        let expected = try #require(try StandardCatalogPromptTests.upstreamLines()[name])
        let single = Catalog(components: [StandardCatalogPromptTests.stripped(definition)])
        let line = single.prompt().split(separator: "\n").first { $0.hasPrefix("- \(name):") }
        #expect(line.map(String.init) == expected)
    }

    @Test func passwordValueIsASecretProp() {
        #expect(JRInput.definition.secretProps == ["value"])
        #expect(JRInput.catalogDefinition.secretProps == ["value"])
        #expect(JRTextarea.definition.secretProps.isEmpty)
    }

    @Test(arguments: Group2DefinitionTests.group2)
    func everyControlHasALabelInTheAudit(_ name: String) throws {
        // The label prop the audit reads exists on each labelled control.
        let definition = try #require(try Catalog.standard.component(named: name))
        guard case .object(let fields) = definition.props.kind else { return }
        let names = Set(fields.map(\.name))
        let labelled =
            !names.isDisjoint(with: AccessibilityAudit.labelProps)
            || names.contains("items") || names.contains("buttons") || names.contains("columns")
            || name == "Spinner" || name == "Slider" || name == "Progress"
        #expect(labelled)
    }
}

/// Macro-decoded props: missing, `null` and wrong-typed values.
@MainActor
@Suite struct Group2PropDecodingTests {
    @Test func missingAndNullPropsTakeDefaults() {
        let button = JRButton(context: JRRenderContext(id: "b", props: ["label": nil]))
        #expect(button.label == "")
        #expect(button.variant == nil)
        let nulled = JRButton(
            context: JRRenderContext(id: "b", props: ["label": "Go", "disabled": .some(.null)]))
        #expect(nulled.disabled == nil)
        #expect(nulled.label == "Go")
    }

    @Test func numbersAndStringsCoerce() {
        let progress = JRProgress(
            context: JRRenderContext(id: "p", props: ["value": "72", "max": .number(100)]))
        #expect(progress.value == 72)
        #expect(progress.max == 100)
        let select = JRSelect(
            context: JRRenderContext(
                id: "s",
                props: ["label": "Role", "name": "r", "options": ["a", .number(2), .null]]))
        #expect(select.options == ["a", "2"])
    }

    @Test func variantEnumsCoverTheSchemas() {
        #expect(
            JRButtonVariant.allCases.map(\.rawValue) == [
                "primary", "secondary", "danger", "destructive", "plain",
            ])
        #expect(JRButtonVariant.destructive.canonical == .danger)
        #expect(JRInputType.allCases.count == 4)
        #expect(JRToggleVariant.allCases.map(\.rawValue) == ["default", "outline"])
        #expect(JRToggleGroupType.allCases.map(\.rawValue) == ["single", "multiple"])
        #expect(JRAvatarSize.allCases.map(\.diameter) == [24, 32, 44])
        #expect(JRImageFit.allCases.map(\.rawValue) == ["contain", "cover"])
    }
}
