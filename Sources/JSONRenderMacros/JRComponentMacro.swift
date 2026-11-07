// Owner: jr-1b (wave 1). Fresh implementation; the idea follows rxtech-lab's component macro
// (MIT, credited in NOTICE).
import SwiftDiagnostics
public import SwiftSyntax
import SwiftSyntaxBuilder
public import SwiftSyntaxMacros

/// `@JRComponent`: generates `definition`, `jrContext`, `init(context:)` and the
/// `JRComponentType` conformance from the struct's `@JRProp` properties.
public struct JRComponentMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(node: Syntax(node), message: JRDiagnostic.notAStruct))
            return []
        }
        let arguments = ComponentArguments(node)
        guard let name = arguments.name else {
            context.diagnose(Diagnostic(node: Syntax(node), message: JRDiagnostic.missingName))
            return []
        }
        var props: [PropInfo] = []
        var names: Set<String> = []
        var failed = false
        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self),
                let attribute = variable.jrPropAttribute
            else { continue }
            switch PropInfo.parse(variable, attribute: attribute) {
            case .success(let prop):
                if !names.insert(prop.jsonName).inserted {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(variable),
                            message: JRDiagnostic.duplicateProp(prop.jsonName)))
                    failed = true
                } else {
                    props.append(prop)
                }
            case .failure(let message):
                context.diagnose(Diagnostic(node: Syntax(variable), message: message))
                failed = true
            }
        }
        guard !failed else { return [] }

        var definitionArguments = ["name: \(name)"]
        if let description = arguments.description {
            definitionArguments.append("description: \(description)")
        }
        let fields = props.map(\.fieldExpression)
        definitionArguments.append(
            fields.isEmpty
                ? "props: .object([])"
                : "props: .object([\n\(fields.map { "        \($0)," }.joined(separator: "\n"))\n    ])"
        )
        if let slots = arguments.slots { definitionArguments.append("slots: \(slots)") }
        if let events = arguments.events { definitionArguments.append("events: \(events)") }
        let secrets = props.filter(\.secret).map { "\"\($0.jsonName)\"" }
        if !secrets.isEmpty {
            definitionArguments.append("secretProps: [\(secrets.joined(separator: ", "))]")
        }
        let definition: DeclSyntax = """
            nonisolated public static let definition = ComponentDefinition(
                \(raw: definitionArguments.joined(separator: ",\n    "))
            )
            """
        let contextProperty: DeclSyntax = "public let jrContext: JRRenderContext"
        let assignments = (["self.jrContext = context"] + props.map(\.assignment))
            .map { "    \($0)" }.joined(separator: "\n")
        let initializer: DeclSyntax = """
            public init(context: JRRenderContext) {
            \(raw: assignments)
            }
            """
        return [definition, contextProperty, initializer]
    }

    public static func expansion(
        of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self), !protocols.isEmpty else { return [] }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): JRComponentType {}")]
    }
}

/// `@JRProp`: a marker read by `@JRComponent`. It expands to nothing.
public struct JRPropMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

// MARK: - Arguments

/// The `@JRComponent` arguments, kept as source text.
struct ComponentArguments {
    var name: String?
    var description: String?
    var slots: String?
    var events: String?

    init(_ node: AttributeSyntax) {
        guard let list = node.arguments?.as(LabeledExprListSyntax.self) else { return }
        for argument in list {
            let text = argument.expression.trimmedDescription
            switch argument.label?.text {
            case nil: name = text
            case "description": description = text
            case "slots": slots = text
            case "events": events = text
            default: break
            }
        }
    }
}

extension VariableDeclSyntax {
    /// The `@JRProp` attribute, if present.
    var jrPropAttribute: AttributeSyntax? {
        for element in attributes {
            if let attribute = element.as(AttributeSyntax.self),
                attribute.attributeName.trimmedDescription == "JRProp"
            {
                return attribute
            }
        }
        return nil
    }
}

// MARK: - Props

/// One `@JRProp` property.
struct PropInfo {
    /// The Swift identifier as written (backticks kept).
    var identifier: String
    /// The prop name in JSON (backticks removed).
    var jsonName: String
    var schema: String
    var description: String?
    var decoder: String
    /// The value for a missing prop: the default, the type's zero, or `nil` for optionals.
    var fallback: String?
    var secret: Bool

    var fieldExpression: String {
        var text = ".init(name: \"\(jsonName)\", schema: \(schema)"
        if let description { text += ", description: \(description)" }
        return text + ")"
    }

    var assignment: String {
        let read = "\(decoder)(context.props[\"\(jsonName)\"] ?? nil)"
        guard let fallback else { return "self.\(identifier) = \(read)" }
        return "self.\(identifier) = \(read) ?? \(fallback)"
    }

    enum ParseResult {
        case success(PropInfo)
        case failure(JRDiagnostic)
    }

    static func parse(_ variable: VariableDeclSyntax, attribute: AttributeSyntax) -> ParseResult {
        guard variable.bindings.count == 1, let binding = variable.bindings.first,
            let pattern = binding.pattern.as(IdentifierPatternSyntax.self)
        else { return .failure(.singleProperty) }
        let identifier = pattern.identifier.text
        let jsonName = identifier.filter { $0 != "`" }
        guard let type = binding.typeAnnotation?.type else {
            return .failure(.missingType(jsonName))
        }
        if let accessors = binding.accessorBlock, isComputed(accessors) {
            return .failure(.computedProperty(jsonName))
        }
        let defaultValue = binding.initializer?.value.trimmedDescription
        if variable.bindingSpecifier.tokenKind == .keyword(.let), defaultValue != nil {
            return .failure(.letWithDefault(jsonName))
        }
        guard let mapped = TypeMapping(type) else {
            return .failure(.unsupportedType(jsonName, type.trimmedDescription))
        }

        var description: String?
        var oneOf: String?
        var secret = false
        for argument in attribute.arguments?.as(LabeledExprListSyntax.self) ?? [] {
            switch argument.label?.text {
            case "description": description = argument.expression.trimmedDescription
            case "oneOf": oneOf = argument.expression.trimmedDescription
            case "secret":
                secret =
                    argument.expression.as(BooleanLiteralExprSyntax.self)?.literal.tokenKind
                    == .keyword(.true)
            default: break
            }
        }
        var schema = mapped.schema
        if let oneOf {
            guard mapped.isString else { return .failure(.oneOfOnNonString(jsonName)) }
            schema = ".enum(\(oneOf))"
        }
        if mapped.isOptional { schema += ".nullable()" }
        if defaultValue != nil { schema += ".optional()" }
        return .success(
            PropInfo(
                identifier: identifier, jsonName: jsonName, schema: schema,
                description: description, decoder: mapped.decoder,
                fallback: defaultValue ?? (mapped.isOptional ? nil : mapped.zero), secret: secret))
    }
}

/// `true` for a getter body or `get`/`set` accessors; `false` for `willSet`/`didSet` only.
private func isComputed(_ block: AccessorBlockSyntax) -> Bool {
    switch block.accessors {
    case .getter:
        return true
    case .accessors(let list):
        return list.contains { accessor in
            let kind = accessor.accessorSpecifier.tokenKind
            return kind != .keyword(.willSet) && kind != .keyword(.didSet)
        }
    }
}

/// The schema, decoder and zero value of a supported prop type.
struct TypeMapping {
    /// The schema without the top-level `.nullable()`.
    var schema: String
    var decoder: String
    var zero: String
    var isOptional: Bool
    /// `String` or `String?` (where `oneOf` is allowed).
    var isString: Bool

    init?(_ type: TypeSyntax) {
        if let wrapped = TypeMapping.optionalWrapped(type) {
            guard let inner = TypeMapping(wrapped), !inner.isOptional else { return nil }
            self = inner
            isOptional = true
            return
        }
        if let element = TypeMapping.arrayElement(type) {
            guard let inner = TypeMapping(element), !inner.isOptional else { return nil }
            schema = ".array(\(inner.schema))"
            decoder = "JRPropDecode.array(\(inner.decoder))"
            zero = "[]"
            isOptional = false
            isString = false
            return
        }
        let name = type.trimmedDescription.split(separator: ".").last.map(String.init) ?? ""
        let scalar: (String, String, String)? =
            switch name {
            case "String": (".string", "JRPropDecode.string", "\"\"")
            case "Double": (".number", "JRPropDecode.double", "0")
            case "Float": (".number", "JRPropDecode.float", "0")
            case "CGFloat": (".number", "JRPropDecode.cgFloat", "0")
            case "Int": (".number", "JRPropDecode.int", "0")
            case "Bool": (".boolean", "JRPropDecode.bool", "false")
            case "JSONValue": (".any", "JRPropDecode.json", ".null")
            default: nil
            }
        guard let scalar else { return nil }
        (schema, decoder, zero) = scalar
        isOptional = false
        isString = name == "String"
    }

    private static func optionalWrapped(_ type: TypeSyntax) -> TypeSyntax? {
        if let optional = type.as(OptionalTypeSyntax.self) { return optional.wrappedType }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Optional",
            let argument = identifier.genericArgumentClause?.arguments.first
        {
            return argument.argument.as(TypeSyntax.self)
        }
        return nil
    }

    private static func arrayElement(_ type: TypeSyntax) -> TypeSyntax? {
        if let array = type.as(ArrayTypeSyntax.self) { return array.element }
        if let identifier = type.as(IdentifierTypeSyntax.self), identifier.name.text == "Array",
            let argument = identifier.genericArgumentClause?.arguments.first
        {
            return argument.argument.as(TypeSyntax.self)
        }
        return nil
    }
}

// MARK: - Diagnostics

struct JRDiagnostic: DiagnosticMessage {
    let message: String
    let id: String

    var diagnosticID: MessageID { MessageID(domain: "JSONRenderMacros", id: id) }
    var severity: DiagnosticSeverity { .error }

    static let notAStruct = JRDiagnostic(
        message: "@JRComponent can only be applied to a struct", id: "notAStruct")
    static let missingName = JRDiagnostic(
        message: "@JRComponent needs the component name as its first argument", id: "missingName")
    static let singleProperty = JRDiagnostic(
        message: "@JRProp must be on a single stored property with a simple name",
        id: "singleProperty")

    static func missingType(_ name: String) -> JRDiagnostic {
        JRDiagnostic(message: "@JRProp '\(name)' needs an explicit type", id: "missingType")
    }

    static func computedProperty(_ name: String) -> JRDiagnostic {
        JRDiagnostic(
            message: "@JRProp '\(name)' is a computed property; use a stored 'var'",
            id: "computedProperty")
    }

    static func letWithDefault(_ name: String) -> JRDiagnostic {
        JRDiagnostic(
            message: "@JRProp '\(name)' has a default value; declare it with 'var'",
            id: "letWithDefault")
    }

    static func unsupportedType(_ name: String, _ type: String) -> JRDiagnostic {
        JRDiagnostic(
            message:
                "unsupported @JRProp type '\(type)' for '\(name)'; use String, Double, Float, CGFloat, Int, Bool, JSONValue, or an array or optional of those",
            id: "unsupportedType")
    }

    static func oneOfOnNonString(_ name: String) -> JRDiagnostic {
        JRDiagnostic(
            message: "@JRProp(oneOf:) on '\(name)' needs a String or String? property",
            id: "oneOfOnNonString")
    }

    static func duplicateProp(_ name: String) -> JRDiagnostic {
        JRDiagnostic(message: "duplicate @JRProp name '\(name)'", id: "duplicateProp")
    }
}
