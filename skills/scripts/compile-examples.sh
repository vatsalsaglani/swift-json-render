#!/bin/sh
# Compiles every ```swift block of both skills, the README and the DocC articles against this
# checkout, so a renamed type or argument breaks a build instead of a user's prompt.
#
#   skills/scripts/compile-examples.sh
#
# Needs macOS and the Swift toolchain. It builds a scratch package in a temporary directory
# (never inside the repository; the directory name of the checkout is the package identity of
# the path dependency) and deletes it on exit. Exit 0 when every block compiles.
#
# A block that starts a Package.swift snippet, or a `// not compiled: <reason>` comment (names
# internal to a package module), is skipped. Every other block is built: a block
# of statements is wrapped in a main-actor throwing function; a block with no import line gets
# `Foundation` and `JSONRenderCore`.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
[ "$(uname -s)" = "Darwin" ] || { echo "the example build needs macOS" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/jr-examples.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

pkg="$work/examples"
mkdir -p "$pkg/Sources"
repo_name=$(basename "$root")
# Each block is its own module, so two documents can declare the same type name.
python3 -I -B "$root/skills/scripts/extract-swift-examples.py" "$root" "$pkg/Sources" | tee "$work/extract.log"
modules=$(sed -n 's/^modules: //p' "$work/extract.log")
{
cat <<PKG
// swift-tools-version: 6.2
import PackageDescription

// An app uses plain imports, so the samples build with Swift 6 mode and nothing else.
let strict: [SwiftSetting] = [.swiftLanguageMode(.v6)]
let products: [Target.Dependency] = [
    .product(name: "JSONRender", package: "$repo_name"),
    .product(name: "JSONRenderCore", package: "$repo_name"),
    .product(name: "JSONRenderClient", package: "$repo_name"),
    .product(name: "JSONRenderSwiftUI", package: "$repo_name"),
    .product(name: "JSONRenderStandardCatalog", package: "$repo_name"),
    .product(name: "JSONRenderCharts", package: "$repo_name"),
    .product(name: "JSONRenderCompose", package: "$repo_name"),
]

let package = Package(
    name: "examples",
    platforms: [.macOS(.v14)],
    dependencies: [.package(path: "$root")],
    targets: [
PKG
for m in $modules; do
  echo "        .target(name: \"$m\", dependencies: products, swiftSettings: strict),"
done
cat <<PKG
    ]
)
PKG
} >"$pkg/Package.swift"
swift build --package-path "$pkg"
echo "skill examples compile"
