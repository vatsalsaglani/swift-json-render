extension Catalog {
    /// The spec shape of the upstream React schema, as a `PropSchema`:
    /// `{ root: string, elements: Record<string, { type, props, children, slots?, visible?,
    /// repeat? }> }`. `type` is `string` (no components), a literal (one) or an enum;
    /// `props` is the single component's schema or `Record<string, unknown>`.
    public var specSchema: PropSchema {
        let names = componentNames
        let type: PropSchema =
            switch names.count {
            case 0: .string
            case 1: .literal(.string(names[0]))
            default: .enum(names)
            }
        let props: PropSchema = components.count == 1 ? components[0].props : .record(.any)
        let element = PropSchema.object([
            .init(name: "type", schema: type),
            .init(name: "props", schema: props),
            .init(name: "children", schema: .array(.string)),
            .init(name: "slots", schema: .record(.array(.string)).optional()),
            .init(name: "visible", schema: PropSchema.any.optional()),
            .init(name: "repeat", schema: PropSchema.any.optional()),
        ])
        return .object([
            .init(name: "root", schema: .string),
            .init(name: "elements", schema: .record(element)),
        ])
    }

    /// Upstream `catalog.jsonSchema({ strict })` for the React schema.
    ///
    /// Strict mode reproduces upstream exactly, including its limit: records are opaque, so
    /// `elements` admits no keys. A structured-output call with the strict schema cannot
    /// produce a usable spec; use the prompt and JSONL instead (see the reference note).
    public func jsonSchema(strict: Bool = true) -> JSONValue {
        specSchema.jsonSchema(strict: strict)
    }

    /// `JSON.stringify(jsonSchema(strict:))` with upstream key order.
    public func jsonSchemaText(strict: Bool = true) -> String {
        specSchema.jsonSchemaText(strict: strict)
    }
}
