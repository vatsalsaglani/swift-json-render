import JSONRenderCore
import JSONRenderSwiftUI
import SwiftUI
import Testing

@testable import JSONRenderStandardCatalog

/// Definition shape of jr-3's 18 components: prop order, required props, slots, events.
@Suite struct ComponentDefinitionTests {
    struct Shape: Sendable, CustomTestStringConvertible {
        let definition: ComponentDefinition
        let props: [String]
        let required: [String]
        let slots: [String]
        let events: [String]
        var testDescription: String { definition.name }
    }

    static let shapes: [Shape] = [
        Shape(
            definition: JRCard.definition,
            props: ["title", "description", "maxWidth", "centered", "className", "variant"],
            required: [], slots: ["default", "header", "footer"], events: []),
        Shape(
            definition: JRStack.definition,
            props: ["direction", "gap", "align", "justify", "className", "wrap"], required: [],
            slots: ["default"], events: []),
        Shape(
            definition: JRGrid.definition, props: ["columns", "gap", "className"], required: [],
            slots: ["default"], events: []),
        Shape(
            definition: JRSeparator.definition, props: ["orientation"], required: [], slots: [],
            events: []),
        Shape(
            definition: JRTabs.catalogDefinition,
            props: ["tabs", "defaultValue", "value", "variant"], required: ["tabs"],
            slots: ["default"], events: ["change"]),
        Shape(
            definition: JRAccordion.catalogDefinition, props: ["items", "type"],
            required: ["items"], slots: [], events: []),
        Shape(
            definition: JRCollapsible.definition, props: ["title", "defaultOpen", "open"],
            required: ["title"], slots: ["default"], events: []),
        Shape(
            definition: JRPagination.definition, props: ["totalPages", "page"],
            required: ["totalPages"], slots: [], events: ["change"]),
        Shape(
            definition: JRDialog.definition, props: ["title", "description", "openPath", "open"],
            required: ["title", "openPath"], slots: ["default", "footer"], events: []),
        Shape(
            definition: JRDrawer.definition, props: ["title", "description", "openPath", "open"],
            required: ["title", "openPath"], slots: ["default", "footer"], events: []),
        Shape(
            definition: JRTooltip.definition, props: ["content", "text"],
            required: ["content", "text"], slots: [], events: []),
        Shape(
            definition: JRPopover.definition, props: ["trigger", "content"],
            required: ["trigger", "content"], slots: [], events: []),
        Shape(
            definition: JRDropdownMenu.catalogDefinition, props: ["label", "items", "value"],
            required: ["label", "items"], slots: [], events: ["select"]),
        Shape(
            definition: JRHeading.definition, props: ["text", "level"], required: ["text"],
            slots: [], events: []),
        Shape(
            definition: JRText.definition, props: ["text", "variant"], required: ["text"],
            slots: [], events: []),
        Shape(
            definition: JRBadge.definition, props: ["text", "variant"], required: ["text"],
            slots: [], events: []),
        Shape(
            definition: JRAlert.definition, props: ["title", "message", "type"],
            required: ["title"], slots: [], events: []),
        Shape(
            definition: JRSkeleton.definition, props: ["width", "height", "rounded", "shape"],
            required: [], slots: [], events: []),
    ]

    @Test(arguments: ComponentDefinitionTests.shapes)
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
        #expect(shape.definition.slots == shape.slots)
        #expect(shape.definition.events == shape.events)
        #expect(!shape.definition.description.isEmpty)
        #expect(shape.definition.secretProps.isEmpty)
    }

    @Test func objectListSchemasAreSpelledOut() {
        #expect(
            JRTabs.catalogDefinition.props.formatted().contains(
                "tabs: Array<{ label: string, value: string }>"))
        #expect(
            JRAccordion.catalogDefinition.props.formatted().contains(
                "items: Array<{ title: string, content: string }>"))
        #expect(
            JRDropdownMenu.catalogDefinition.props.formatted().contains(
                "items: Array<{ label: string, value: string }>"))
    }
}

/// Macro-decoded props: values, missing props and JSON null.
@MainActor
@Suite struct ComponentDecodeTests {
    private func context(_ props: [String: JSONValue?]) -> JRRenderContext {
        JRRenderContext(id: "x", props: props)
    }

    @Test func cardDecodesAndDefaults() {
        let card = JRCard(
            context: context([
                "title": "T", "description": .some(.null), "maxWidth": "md", "centered": "true",
            ]))
        #expect(card.title == "T")
        #expect(card.description == nil)
        #expect(card.maxWidth == "md")
        #expect(card.centered == true)
        #expect(card.variant == nil)
        #expect(JRCardWidth(rawValue: "md")?.points == 448)
        #expect(JRCardWidth.full.points == nil)
    }

    @Test func requiredStringFallsBackToEmpty() {
        #expect(JRText(context: context([:])).text == "")
        #expect(JRText(context: context(["text": .some(.null)])).text == "")
        #expect(JRText(context: context(["text": 42])).text == "42")
        #expect(JRHeading(context: context(["text": "H"])).level == nil)
    }

    @Test func numbersAndBooleansCoerce() {
        let grid = JRGrid(context: context(["columns": "3"]))
        #expect(grid.columns == 3)
        let pagination = JRPagination(context: context(["totalPages": 4.6, "page": nil]))
        #expect(pagination.totalPages == 5)
        #expect(pagination.page == nil)
        let collapsible = JRCollapsible(context: context(["title": "T", "defaultOpen": "false"]))
        #expect(collapsible.defaultOpen == false)
    }

    @Test func objectListsDecode() {
        let tabs = JRTabs(
            context: context([
                "tabs": [["label": "A", "value": "a"], .null, ["label": "B"], ["value": "a"]]
            ]))
        #expect(tabs.tabs.count == 3)  // null dropped by the macro decoder
        let items = LabelValueItem.list(tabs.tabs)
        // A missing value uses the label; a duplicate value is dropped.
        #expect(items.map(\.value) == ["a", "B"])
        #expect(items.map(\.label) == ["A", "B"])
    }

    @Test func variantEnumsCoverTheSchemaValues() {
        func values(_ definition: ComponentDefinition, _ prop: String) -> [String] {
            guard case .object(let fields) = definition.props.kind,
                let field = fields.first(where: { $0.name == prop }),
                case .enum(let values) = field.schema.kind
            else { return [] }
            return values
        }
        #expect(values(JRCard.definition, "variant") == JRCardVariant.allCases.map(\.rawValue))
        #expect(values(JRCard.definition, "maxWidth") == JRCardWidth.allCases.map(\.rawValue))
        #expect(values(JRStack.definition, "align") == JRStackAlign.allCases.map(\.rawValue))
        #expect(values(JRStack.definition, "justify") == JRStackJustify.allCases.map(\.rawValue))
        #expect(values(JRText.definition, "variant") == JRTextVariant.allCases.map(\.rawValue))
        #expect(values(JRHeading.definition, "level") == JRHeadingLevel.allCases.map(\.rawValue))
        #expect(values(JRBadge.definition, "variant") == JRBadgeVariant.allCases.map(\.rawValue))
        #expect(values(JRAlert.definition, "type") == JRAlertType.allCases.map(\.rawValue))
        #expect(values(JRTabs.definition, "variant") == JRTabsVariant.allCases.map(\.rawValue))
        #expect(values(JRAccordion.definition, "type") == JRAccordionMode.allCases.map(\.rawValue))
        #expect(values(JRSkeleton.definition, "shape") == SkeletonShape.allCases.map(\.rawValue))
    }

    @Test func statusVariantsCarryASymbolAndAWord() {
        #expect(JRBadgeVariant.destructive.status == .critical)
        #expect(JRBadgeVariant.default.status == nil)
        for type in JRAlertType.allCases {
            #expect(!type.status.symbol.isEmpty)
            #expect(!type.status.word.isEmpty)
        }
    }

    @Test func skeletonLengths() {
        #expect(SkeletonLength("24px").points == 24)
        #expect(SkeletonLength("24").points == 24)
        #expect(SkeletonLength("1.5rem").points == 24)
        #expect(SkeletonLength("100%").points == nil)
        #expect(SkeletonLength("wide").points == nil)
        #expect(SkeletonLength(nil).points == nil)
        #expect(SkeletonShape.forType("Table") == .tableBody)
        #expect(SkeletonShape.forType("BarChart") == .block)
        #expect(SkeletonShape.forType("Text") == .line)
    }

    @Test func gapScale() {
        #expect(
            ["none", "sm", "md", "lg", "xl"].map { StandardGap.points($0) } == [0, 6, 10, 16, 20])
        #expect(StandardGap.points(nil) == 10)
    }

    @Test func replacingPropKeepsOrderAndNullability() {
        let definition = JRTabs.definition.replacingProp("tabs", with: .string)
        guard case .object(let fields) = definition.props.kind else { return }
        #expect(fields.map(\.name) == ["tabs", "defaultValue", "value", "variant"])
        #expect(fields[0].schema.kind == .string)
        #expect(!fields[0].schema.isNullable)
    }
}
