import Foundation
import JSONRenderClient
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

@testable import JSONRenderMacros

private let macroSpecs: [String: MacroSpec] = [
    "JRComponent": MacroSpec(type: JRComponentMacro.self, conformances: ["JRComponentType"]),
    "JRProp": MacroSpec(type: JRPropMacro.self),
]

private func expand(
    _ source: String, _ expected: String, diagnostics: [DiagnosticSpec] = [],
    sourceLocation: SourceLocation = #_sourceLocation
) {
    assertMacroExpansion(
        source, expandedSource: expected, diagnostics: diagnostics, macroSpecs: macroSpecs,
        failureHandler: { failure in
            Issue.record(Comment(rawValue: failure.message), sourceLocation: sourceLocation)
        })
}

@Suite("@JRComponent expansion")
struct JRComponentMacroTests {
    @Test("The Stat example: required, nullable, default and oneOf props")
    func stat() {
        expand(
            """
            @JRComponent("Stat", description: "One number")
            struct Stat {
                @JRProp var label: String
                @JRProp(description: "Trend") var delta: Double?
                @JRProp(oneOf: ["good", "warning"]) var intent: String = "good"
            }
            """,
            """
            struct Stat {
                var label: String
                var delta: Double?
                var intent: String = "good"

                nonisolated public static let definition = ComponentDefinition(
                    name: "Stat",
                    description: "One number",
                    props: .object([
                        .init(name: "label", schema: .string),
                        .init(name: "delta", schema: .number.nullable(), description: "Trend"),
                        .init(name: "intent", schema: .enum(["good", "warning"]).optional()),
                    ])
                )

                public let jrContext: JRRenderContext

                public init(context: JRRenderContext) {
                    self.jrContext = context
                    self.label = JRPropDecode.string(context.props["label"] ?? nil) ?? ""
                    self.delta = JRPropDecode.double(context.props["delta"] ?? nil)
                    self.intent = JRPropDecode.string(context.props["intent"] ?? nil) ?? "good"
                }
            }

            extension Stat: nonisolated JRComponentType {
            }
            """)
    }

    @Test("Arrays, JSONValue lists, Int, Bool, slots, events and secret props")
    func collections() {
        expand(
            """
            @JRComponent("Tabs", slots: ["default"], events: ["change"])
            struct Tabs {
                @JRProp var tabs: [JSONValue]
                @JRProp var rows: [[String]]?
                @JRProp var count: Int
                @JRProp var open: Bool = false
                @JRProp(secret: true) var token: String?
                @JRProp var data: JSONValue
                var notAProp = 1
            }
            """,
            """
            struct Tabs {
                var tabs: [JSONValue]
                var rows: [[String]]?
                var count: Int
                var open: Bool = false
                var token: String?
                var data: JSONValue
                var notAProp = 1

                nonisolated public static let definition = ComponentDefinition(
                    name: "Tabs",
                    props: .object([
                        .init(name: "tabs", schema: .array(.any)),
                        .init(name: "rows", schema: .array(.array(.string)).nullable()),
                        .init(name: "count", schema: .number),
                        .init(name: "open", schema: .boolean.optional()),
                        .init(name: "token", schema: .string.nullable()),
                        .init(name: "data", schema: .any),
                    ]),
                    slots: ["default"],
                    events: ["change"],
                    secretProps: ["token"]
                )

                public let jrContext: JRRenderContext

                public init(context: JRRenderContext) {
                    self.jrContext = context
                    self.tabs = JRPropDecode.array(JRPropDecode.json)(context.props["tabs"] ?? nil) ?? []
                    self.rows = JRPropDecode.array(JRPropDecode.array(JRPropDecode.string))(context.props["rows"] ?? nil)
                    self.count = JRPropDecode.int(context.props["count"] ?? nil) ?? 0
                    self.open = JRPropDecode.bool(context.props["open"] ?? nil) ?? false
                    self.token = JRPropDecode.string(context.props["token"] ?? nil)
                    self.data = JRPropDecode.json(context.props["data"] ?? nil) ?? .null
                }
            }

            extension Tabs: nonisolated JRComponentType {
            }
            """)
    }

    @Test("Diagnostics: non-struct, unsupported type, oneOf on non-String, let with default")
    func diagnostics() {
        expand(
            """
            @JRComponent("X")
            class X {}
            """,
            """
            class X {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@JRComponent can only be applied to a struct", line: 1, column: 1)
            ])
        expand(
            """
            @JRComponent("X")
            struct X {
                @JRProp var when: Date
                @JRProp(oneOf: ["a"]) var n: Int
                @JRProp let fixed: String = "x"
            }
            """,
            """
            struct X {
                var when: Date
                var n: Int
                let fixed: String = "x"
            }

            extension X: nonisolated JRComponentType {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message:
                        "unsupported @JRProp type 'Date' for 'when'; use String, Double, Float, CGFloat, Int, Bool, JSONValue, or an array or optional of those",
                    line: 3, column: 5),
                DiagnosticSpec(
                    message: "@JRProp(oneOf:) on 'n' needs a String or String? property", line: 4,
                    column: 5),
                DiagnosticSpec(
                    message: "@JRProp 'fixed' has a default value; declare it with 'var'", line: 5,
                    column: 5),
            ])
    }

    @Test("Diagnostic: @JRProp on a computed property")
    func computed() {
        expand(
            """
            @JRComponent("X")
            struct X {
                @JRProp var label: String { "x" }
                @JRProp var count: Int = 0 {
                    didSet {}
                }
            }
            """,
            """
            struct X {
                var label: String { "x" }
                var count: Int = 0 {
                    didSet {}
                }
            }

            extension X: nonisolated JRComponentType {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@JRProp 'label' is a computed property; use a stored 'var'", line: 3,
                    column: 5)
            ])
    }
}

/// A real `@JRComponent` type (Core protocol only; no SwiftUI).
@JRComponent("Metric", description: "A number with a label", events: ["press"])
struct Metric {
    @JRProp var label: String
    @JRProp var value: Double?
    @JRProp(oneOf: ["good", "bad"]) var tone: String = "good"
    @JRProp var items: [JSONValue]
    @JRProp(secret: true) var pin: String?
}

@Suite("@JRComponent end to end")
struct JRComponentEndToEndTests {
    @Test("The definition and the conformance")
    func definition() throws {
        #expect(Metric.definition.name == "Metric")
        #expect(Metric.definition.events == ["press"])
        #expect(Metric.definition.secretProps == ["pin"])
        #expect(
            Metric.definition.props.formatted()
                == "{ label: string, value?: number, tone?: \"good\" | \"bad\", items: Array<unknown>, pin?: string }"
        )
        var catalog = Catalog()
        try catalog.register(Metric.self)
        #expect(catalog.componentNames == ["Metric"])
    }

    @MainActor
    @Test("init(context:) coerces, defaults and keeps zero values")
    func initialiser() {
        let full = Metric(
            context: JRRenderContext(
                id: "m",
                props: [
                    "label": 42, "value": "3.5", "tone": "bad", "items": [["a": 1]],
                    "pin": Optional<JSONValue>.none,
                ]))
        #expect(full.label == "42")
        #expect(full.value == 3.5)
        #expect(full.tone == "bad")
        #expect(full.items == [["a": 1]])
        #expect(full.pin == nil)
        #expect(full.jrContext.id == "m")
        let empty = Metric(context: JRRenderContext(id: "e", props: ["value": .null]))
        #expect(empty.label == "")
        #expect(empty.value == nil)
        #expect(empty.tone == "good")
        #expect(empty.items.isEmpty)
    }
}
