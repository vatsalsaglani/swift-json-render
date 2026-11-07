// Owner: jr-3b (wave 2). Prop schemas of the group-2 components that the macro cannot express.
internal import JSONRenderCore

extension StandardSchemas {
    /// `Array<{ type: string, message: string, args?: Record<string, unknown> }>`.
    static let checks = PropSchema.array(
        .object([
            PropSchema.Field(name: "type", schema: .string),
            PropSchema.Field(name: "message", schema: .string),
            PropSchema.Field(name: "args", schema: PropSchema.record(.any).optional()),
        ]))

    /// `Array<string>`.
    static let stringList = PropSchema.array(.string)

    /// `Array<Array<string>>`.
    static let stringRows = PropSchema.array(.array(.string))

    /// `Array<{ title?: string, description?: string }>`.
    static let carouselItems = PropSchema.array(
        .object([
            PropSchema.Field(name: "title", schema: PropSchema.string.nullable().optional()),
            PropSchema.Field(name: "description", schema: PropSchema.string.nullable().optional()),
        ]))
}

extension ComponentDefinition {
    /// A copy with several prop schemas replaced.
    func replacingProps(_ schemas: [(String, PropSchema)]) -> ComponentDefinition {
        schemas.reduce(self) { $0.replacingProp($1.0, with: $1.1) }
    }
}
