#!/bin/sh
# Writes site/data/catalog.generated.json from the real Swift catalogs (Catalog.standard and
# Catalog.charts): name, description, slots, events, example and props of every component.
#
#   site/tools/dump-catalog.sh [output-file]
#
# Then run `node site/tools/merge-catalog.mjs` and `node site/tools/sync-data.mjs`.
#
# Needs macOS and the Swift toolchain. It builds a scratch package in a temporary directory
# (never inside the repository) and deletes it on exit. Linux is not needed.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
out="${1:-$root/site/data/catalog.generated.json}"
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
[ "$(uname -s)" = "Darwin" ] || { echo "the catalog dump needs macOS" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/jr-dump.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

pkg="$work/dump"
mkdir -p "$pkg/Sources/dump"
repo_name=$(basename "$root")
cat >"$pkg/Package.swift" <<PKG
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "dump",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "$root")],
    targets: [
        .executableTarget(
            name: "dump",
            dependencies: [
                .product(name: "JSONRenderCore", package: "$repo_name"),
                .product(name: "JSONRenderStandardCatalog", package: "$repo_name"),
                .product(name: "JSONRenderCharts", package: "$repo_name"),
            ])
    ]
)
PKG
cat >"$pkg/Sources/dump/main.swift" <<'SWIFT'
import Foundation
import JSONRenderCharts
import JSONRenderCore
import JSONRenderStandardCatalog

struct Prop: Encodable {
    let name: String
    let type: String
    let required: Bool
    let note: String
}

struct Entry: Encodable {
    let name: String
    let description: String
    let slots: [String]
    let events: [String]
    let example: [String: JSONValue]?
    let props: [Prop]
}

struct Document: Encodable {
    let generatedFrom: String
    let standard: [Entry]
    let charts: [Entry]
}

/// The text a reader sees for a prop type.
func typeText(_ schema: PropSchema) -> String {
    var text: String
    switch schema.kind {
    case .string: text = "string"
    case .number: text = "number"
    case .boolean: text = "boolean"
    case .any: text = "any"
    case .literal(let value):
        if case .string(let s) = value {
            text = "\"\(s)\""
        } else {
            let data = (try? JSONEncoder().encode(value)) ?? Data()
            text = String(decoding: data, as: UTF8.self)
        }
    case .enum(let values): text = "enum(" + values.joined(separator: " | ") + ")"
    case .array(let element): text = "array<" + typeText(element) + ">"
    case .object(let fields): text = "{ " + fields.map(\.name).joined(separator: ", ") + " }"
    case .record(let value): text = "record<" + typeText(value) + ">"
    case .union(let options): text = options.map(typeText).joined(separator: " | ")
    }
    if schema.isNullable { text += " | null" }
    return text
}

func entries(_ catalog: Catalog) -> [Entry] {
    catalog.components.map { definition in
        var props: [Prop] = []
        if case .object(let fields) = definition.props.kind {
            // The prompt prints `?` for a prop that is optional or nullable, so `required`
            // follows it, and the top-level `| null` is left out of the type text.
            props = fields.map {
                var shown = $0.schema
                shown.isNullable = false
                return Prop(
                    name: $0.name, type: typeText(shown),
                    required: !($0.schema.isOptional || $0.schema.isNullable),
                    note: $0.schema.description ?? $0.description ?? "")
            }
        }
        return Entry(
            name: definition.name, description: definition.description,
            slots: definition.slots, events: definition.events, example: definition.example,
            props: props)
    }
}

let revision = CommandLine.arguments[2]
let document = Document(
    generatedFrom: revision, standard: entries(try Catalog.standard),
    charts: entries(try Catalog.charts))
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
var data = try encoder.encode(document)
data.append(0x0A)
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
SWIFT
rev=$(git -C "$root" rev-parse HEAD)
swift run --package-path "$pkg" dump "$out" "$rev"
echo "wrote $out"
