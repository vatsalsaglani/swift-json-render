import Foundation
import Testing

@testable import JSONRenderCore

/// A JSON value that keeps object member order. `JSONValue` and `JSONSerialization` lose
/// it, and the prompt fixtures depend on it (prop order, component order).
indirect enum OrderedNode {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([OrderedNode])
    case object([(String, OrderedNode)])

    subscript(key: String) -> OrderedNode? {
        guard case .object(let members) = self else { return nil }
        return members.first { $0.0 == key }?.1
    }

    var members: [(String, OrderedNode)] {
        if case .object(let members) = self { return members }
        return []
    }

    var items: [OrderedNode] {
        if case .array(let items) = self { return items }
        return []
    }

    var string: String? {
        if case .string(let text) = self { return text }
        return nil
    }

    var jsonValue: JSONValue {
        switch self {
        case .null: .null
        case .bool(let flag): .bool(flag)
        case .number(let number): .number(number)
        case .string(let text): .string(text)
        case .array(let items): .array(items.map(\.jsonValue))
        case .object(let members):
            .object(Dictionary(members.map { ($0.0, $0.1.jsonValue) }, uniquingKeysWith: { $1 }))
        }
    }

    /// A small recursive-descent JSON reader for trusted fixture files.
    static func parse(_ data: Data) throws -> OrderedNode {
        var reader = Reader(bytes: Array(data))
        let node = try reader.value()
        reader.skipSpace()
        guard reader.index == reader.bytes.count else { throw ReaderError.trailing }
        return node
    }

    enum ReaderError: Error {
        case unexpected(Int)
        case trailing
    }

    struct Reader {
        let bytes: [UInt8]
        var index = 0

        mutating func skipSpace() {
            while index < bytes.count, [0x20, 0x0A, 0x0D, 0x09].contains(bytes[index]) {
                index += 1
            }
        }

        mutating func value() throws -> OrderedNode {
            skipSpace()
            guard index < bytes.count else { throw ReaderError.unexpected(index) }
            switch bytes[index] {
            case UInt8(ascii: "{"):
                index += 1
                var members: [(String, OrderedNode)] = []
                skipSpace()
                if bytes[index] == UInt8(ascii: "}") {
                    index += 1
                    return .object(members)
                }
                while true {
                    skipSpace()
                    guard case .string(let key) = try value() else {
                        throw ReaderError.unexpected(index)
                    }
                    skipSpace()
                    guard bytes[index] == UInt8(ascii: ":") else {
                        throw ReaderError.unexpected(index)
                    }
                    index += 1
                    members.append((key, try value()))
                    skipSpace()
                    let next = bytes[index]
                    index += 1
                    if next == UInt8(ascii: "}") { return .object(members) }
                    guard next == UInt8(ascii: ",") else { throw ReaderError.unexpected(index) }
                }
            case UInt8(ascii: "["):
                index += 1
                var items: [OrderedNode] = []
                skipSpace()
                if bytes[index] == UInt8(ascii: "]") {
                    index += 1
                    return .array(items)
                }
                while true {
                    items.append(try value())
                    skipSpace()
                    let next = bytes[index]
                    index += 1
                    if next == UInt8(ascii: "]") { return .array(items) }
                    guard next == UInt8(ascii: ",") else { throw ReaderError.unexpected(index) }
                }
            case UInt8(ascii: "\""):
                let start = index
                index += 1
                while bytes[index] != UInt8(ascii: "\"") {
                    index += bytes[index] == UInt8(ascii: "\\") ? 2 : 1
                }
                index += 1
                let literal = Data(bytes[start..<index])
                return .string(try JSONDecoder().decode(String.self, from: literal))
            case UInt8(ascii: "t"):
                index += 4
                return .bool(true)
            case UInt8(ascii: "f"):
                index += 5
                return .bool(false)
            case UInt8(ascii: "n"):
                index += 4
                return .null
            default:
                let start = index
                while index < bytes.count, "+-0123456789.eE".utf8.contains(bytes[index]) {
                    index += 1
                }
                guard let number = Double(String(decoding: bytes[start..<index], as: UTF8.self))
                else { throw ReaderError.unexpected(start) }
                return .number(number)
            }
        }
    }
}

/// Rebuilds the catalogs behind `upstream/prompt/*.txt` from `prompt/catalogs.json`.
///
/// `catalogs.json` holds each component's props as the JSON Schema of its zod object; this
/// converts it back to a `PropSchema` (keeping field order). It has no `example` values;
/// those come from upstream `packages/shadcn/src/catalog.ts` (below).
enum ShadcnCatalogFixture {
    static func catalog(_ name: String) throws -> Catalog {
        let root = try OrderedNode.parse(ParityFixtures.data("prompt/catalogs.json"))
        guard let components = root["catalogs"]?[name]?["components"] else {
            throw FixtureError.missing(name)
        }
        var catalog = Catalog()
        for (componentName, node) in components.members {
            try catalog.register(
                ComponentDefinition(
                    name: componentName, description: node["description"]?.string ?? "",
                    props: schema(node["props"] ?? .null),
                    slots: node["slots"]?.items.compactMap(\.string) ?? [],
                    events: node["events"]?.items.compactMap(\.string) ?? [],
                    example: name == "shadcn" ? examples[componentName] : nil))
        }
        return catalog
    }

    enum FixtureError: Error { case missing(String) }

    /// JSON Schema (as zod 4 `toJSONSchema` writes it) to `PropSchema`.
    static func schema(_ node: OrderedNode) -> PropSchema {
        var nullable = false
        var result: PropSchema
        if let options = node["anyOf"]?.items {
            let kept = options.filter { $0["type"]?.string != "null" }
            nullable = kept.count != options.count
            result = kept.count == 1 ? schema(kept[0]) : .union(kept.map(schema))
        } else {
            var types = node["type"].map { $0.items.compactMap(\.string) } ?? []
            if let single = node["type"]?.string { types = [single] }
            nullable = types.contains("null")
            let type = types.first { $0 != "null" }
            if let values = node["enum"]?.items.compactMap(\.string) {
                result = .enum(values)
            } else {
                switch type {
                case "string": result = .string
                case "number", "integer": result = .number
                case "boolean": result = .boolean
                case "array": result = .array(schema(node["items"] ?? .object([])))
                case "object":
                    if let properties = node["properties"] {
                        let required = Set(node["required"]?.items.compactMap(\.string) ?? [])
                        result = .object(
                            properties.members.map { key, value in
                                var field = schema(value)
                                if !required.contains(key) { field = field.optional() }
                                return PropSchema.Field(name: key, schema: field)
                            })
                    } else {
                        result = .record(schema(node["additionalProperties"] ?? .object([])))
                    }
                default: result = .any
                }
            }
        }
        if nullable { result = result.nullable() }
        if let description = node["description"]?.string { result = result.described(description) }
        return result
    }

    /// The `example` fields of upstream `packages/shadcn/src/catalog.ts`.
    static let examples: [String: [String: JSONValue]] = [
        "Card": ["title": "Overview", "description": "Your account summary"],
        "Stack": ["direction": "vertical", "gap": "md"],
        "Grid": ["columns": 3, "gap": "md"],
        "Table": [
            "columns": ["Name", "Role"], "rows": [["Alice", "Admin"], ["Bob", "User"]],
        ],
        "Heading": ["text": "Welcome", "level": "h1"],
        "Text": ["text": "Hello, world!"],
        "Avatar": ["name": "Jane Doe", "size": "md"],
        "Badge": ["text": "Active", "variant": "default"],
        "Alert": ["title": "Note", "message": "Your changes have been saved.", "type": "success"],
        "Progress": ["value": 65, "max": 100, "label": "Upload progress"],
        "Input": [
            "label": "Email", "name": "email", "type": "email", "placeholder": "you@example.com",
        ],
        "Button": ["label": "Submit", "variant": "primary"],
    ]
}

/// A line diff for failure messages.
enum TextDiff {
    static func describe(expected: String, actual: String) -> String {
        let lhs = expected.components(separatedBy: "\n")
        let rhs = actual.components(separatedBy: "\n")
        var report: [String] = []
        for index in 0..<max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : "<none>"
            let right = index < rhs.count ? rhs[index] : "<none>"
            if left != right {
                report.append("line \(index + 1):\n- \(left)\n+ \(right)")
                if report.count >= 10 { break }
            }
        }
        return report.joined(separator: "\n")
    }

    static func differingLines(_ expected: String, _ actual: String) -> Int {
        let lhs = expected.components(separatedBy: "\n")
        let rhs = actual.components(separatedBy: "\n")
        return (0..<max(lhs.count, rhs.count)).filter { index in
            (index < lhs.count ? lhs[index] : nil) != (index < rhs.count ? rhs[index] : nil)
        }.count
    }
}
