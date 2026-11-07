import JSONRenderCore

/// Small catalogs built with `Catalog(components:actions:)`, with no SwiftUI, so the suite
/// runs on Linux.
enum MinimalCatalog {
    private static func field(_ name: String, _ schema: PropSchema) -> PropSchema.Field {
        PropSchema.Field(name: name, schema: schema)
    }

    /// The upstream `jev.mdx` catalog (Panel, Input, Button, `savePreferences`) plus a
    /// `Stack`.
    static let jev = Catalog(
        components: [
            ComponentDefinition(
                name: "Panel", props: .object([field("title", .string)]), slots: ["default"]),
            ComponentDefinition(
                name: "Input",
                props: .object([field("label", .string), field("value", .string)])),
            ComponentDefinition(
                name: "Button", props: .object([field("label", .string)]), events: ["press"]),
            ComponentDefinition(name: "Stack", slots: ["default"]),
        ],
        actions: [
            "savePreferences": ActionDefinition(params: .object([field("name", .string)]))
        ])

    /// The catalog of upstream `experimental-compose.test.ts`: Panel with a footer slot,
    /// Readout, Trigger, action `inspect`.
    static let telemetry = Catalog(
        components: [
            ComponentDefinition(name: "Panel", slots: ["default", "footer"]),
            ComponentDefinition(name: "Readout", props: .object([field("value", .number)])),
            ComponentDefinition(
                name: "Trigger", props: .object([field("label", .string)]), events: ["activate"]),
        ],
        actions: ["inspect": ActionDefinition(params: .object([field("reading", .number)]))])

    /// The `dashboard-24` catalog.
    static let dashboard = Catalog(
        components: [
            ComponentDefinition(
                name: "Panel", props: .object([field("title", .string)]),
                slots: ["default", "footer"]),
            ComponentDefinition(name: "Stack", slots: ["default"]),
            ComponentDefinition(name: "Text", props: .object([field("text", .string)])),
            ComponentDefinition(
                name: "Stat",
                props: .object([field("label", .string), field("value", PropSchema.any.optional())])
            ),
            ComponentDefinition(
                name: "Chart",
                props: .object([
                    field("title", .string), field("series", PropSchema.any.optional()),
                ])),
            ComponentDefinition(
                name: "Table",
                props: .object([field("title", .string), field("rows", PropSchema.any.optional())])),
            ComponentDefinition(
                name: "Input",
                props: .object([field("label", .string), field("value", .string)])),
            ComponentDefinition(
                name: "Button", props: .object([field("label", .string)]), events: ["press"]),
        ],
        actions: ["refresh": ActionDefinition(), "export": ActionDefinition()])

    static func named(_ name: String) -> Catalog {
        switch name {
        case "dashboard": dashboard
        case "telemetry": telemetry
        default: jev
        }
    }
}
