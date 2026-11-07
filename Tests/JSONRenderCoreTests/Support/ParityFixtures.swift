import Foundation
import Testing

@testable import JSONRenderCore

/// One row of an upstream fixture `index.json`, with its case file loaded.
struct FixtureCase: Sendable, CustomTestStringConvertible {
    let folder: String
    let name: String
    let kind: String?
    let upstreamTest: String
    /// The raw case JSON, with the `$undefined` / `$nan` markers still in place.
    let json: JSONValue

    var testDescription: String { "\(folder)/\(name) [\(upstreamTest)]" }

    /// A field with the markers applied: `nil` for an absent key or `{ "$undefined": true }`.
    func value(_ key: String) -> JSONValue? {
        json[key].flatMap(ParityFixtures.resolvingMarkers)
    }

    /// A raw field (markers kept). Use it for inputs that are parsed as specs or bindings.
    func raw(_ key: String) -> JSONValue? { json[key] }
}

/// Loads `Tests/ParityFixtures/upstream`, located from this file's path (no bundle
/// resources: the package declares none in wave 1).
enum ParityFixtures {
    static let root: URL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // Support
        .deletingLastPathComponent()  // JSONRenderCoreTests
        .deletingLastPathComponent()  // Tests
        .appendingPathComponent("ParityFixtures")
        .appendingPathComponent("upstream")

    static func url(_ relativePath: String) -> URL {
        root.appendingPathComponent(relativePath)
    }

    static func data(_ relativePath: String) throws -> Data {
        try Data(contentsOf: url(relativePath))
    }

    static func json(_ relativePath: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: data(relativePath))
    }

    /// Every case in `<folder>/index.json`, in index order. Returns `[]` when the folder
    /// cannot be read; `FixtureInventoryTests` fails in that case.
    static func cases(_ folder: String) -> [FixtureCase] {
        guard case .array(let rows)? = try? json("\(folder)/index.json") else { return [] }
        return rows.compactMap { row in
            guard case .string(let name)? = row["name"], case .string(let file)? = row["file"],
                let body = try? json("\(folder)/\(file)")
            else { return nil }
            return FixtureCase(
                folder: folder, name: name, kind: row["kind"]?.stringValue,
                upstreamTest: row["upstreamTest"]?.stringValue ?? "", json: body)
        }
    }

    /// The fixture conventions: `{ "$undefined": true }` is undefined (`nil`, or an absent
    /// key inside an object, or `null` inside an array, as `JSON.stringify` writes it);
    /// `{ "$nan": true }` is `NaN`.
    static func resolvingMarkers(_ value: JSONValue) -> JSONValue? {
        switch value {
        case .object(let members):
            if members.count == 1, members["$undefined"] == .bool(true) { return nil }
            if members.count == 1, members["$nan"] == .bool(true) { return .number(.nan) }
            var result: [String: JSONValue] = [:]
            for (key, member) in members {
                if let resolved = resolvingMarkers(member) { result[key] = resolved }
            }
            return .object(result)
        case .array(let items):
            return .array(items.map { resolvingMarkers($0) ?? .null })
        default:
            return value
        }
    }

    /// The fixture functions for `$computed` (fixture README, `expressions/`).
    static let functions: [String: ComputedFunction] = [
        "fullName": { args in
            .string("\(text(args["first"] ?? nil)) \(text(args["last"] ?? nil))")
        },
        "timestamp": { _ in .number(1_234_567_890) },
        "conditionalSum": { args in
            guard (args["enabled"] ?? nil)?.isTruthy == true else { return .number(0) }
            let x = (args["x"] ?? nil)?.numberValue ?? .nan
            let y = (args["y"] ?? nil)?.numberValue ?? .nan
            return .number(x + y)
        },
    ]

    /// The fixture directives (fixture README, `expressions/`): `$double` resolves its
    /// operand and multiplies by 2; `$upper` resolves its operand and upper-cases `String()`.
    static func directives(_ names: [String]) throws -> DirectiveRegistry {
        var definitions: [DirectiveDefinition] = []
        for name in names {
            switch name {
            case "$double":
                definitions.append(
                    try DirectiveDefinition(name: "$double", schema: .any) { raw, resolver in
                        let operand = raw["$double"].flatMap { resolver.resolveValue($0) }
                        return .number((operand?.numberValue ?? .nan) * 2)
                    })
            case "$upper":
                definitions.append(
                    try DirectiveDefinition(name: "$upper", schema: .any) { raw, resolver in
                        let operand = raw["$upper"].flatMap { resolver.resolveValue($0) }
                        return .string(text(operand).uppercased())
                    })
            default:
                Issue.record("Unknown fixture directive \(name)")
            }
        }
        return DirectiveRegistry(definitions)
    }

    /// JavaScript `String(value)` with `undefined` as `"undefined"`.
    static func text(_ value: JSONValue?) -> String {
        value?.jsString ?? "undefined"
    }

    /// The resolution context a fixture case describes.
    static func context(_ fixture: FixtureCase) throws -> PropResolutionContext {
        var functions: [String: ComputedFunction] = [:]
        if case .array(let names)? = fixture.raw("functions") {
            for case .string(let name) in names {
                functions[name] = ParityFixtures.functions[name]
            }
        }
        var directiveNames: [String] = []
        if case .array(let names)? = fixture.raw("directives") {
            for case .string(let name) in names { directiveNames.append(name) }
        }
        return PropResolutionContext(
            state: fixture.value("state") ?? .object([:]),
            repeatItem: fixture.value("repeatItem"),
            repeatIndex: fixture.value("repeatIndex")?.numberValue.map { Int($0) },
            repeatBasePath: fixture.value("repeatBasePath")?.stringValue.map {
                JSONPointer(lenient: $0)
            },
            functions: functions,
            directives: try directives(directiveNames))
    }
}

extension JSONValue {
    /// Canonical JSON text with sorted keys, for comparisons in tests.
    func canonicalText() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return String(decoding: try encoder.encode(self), as: UTF8.self)
    }
}
