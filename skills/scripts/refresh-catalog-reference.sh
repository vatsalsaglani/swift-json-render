#!/bin/sh
# Regenerates the generated blocks of the "use" skill's component and chart references from
# the package itself: the AVAILABLE COMPONENTS section of Catalog.prompt().
#
#   skills/scripts/refresh-catalog-reference.sh                 # build a scratch package, write both files
#   skills/scripts/refresh-catalog-reference.sh --check         # write nothing; exit 1 when a file is stale
#   skills/scripts/refresh-catalog-reference.sh --standard-prompt FILE --charts-prompt FILE
#                                                               # take prompt text files; no Swift build
#
# Run it at release, after the standard catalog and the charts catalog are complete (36 and 15
# components). It replaces the text between these markers and nothing else:
#
#   <!-- BEGIN GENERATED: components -->  ...  <!-- END GENERATED: components -->   references/components.md
#   <!-- BEGIN GENERATED: charts -->      ...  <!-- END GENERATED: charts -->       references/charts.md
#
# Exit codes: 0 done (or up to date), 1 stale under --check, 2 usage or tooling error,
#             3 a catalog has the wrong number of components (nothing is written).
#
# The default mode needs macOS and the Swift toolchain. It creates its scratch package in a
# temporary directory (never inside the repository) and deletes it on exit.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
refs="$root/skills/json-render-swift-use/references"
expect_standard=36
expect_charts=15
check=0
standard_file=""
charts_file=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) check=1; shift ;;
    --standard-prompt) standard_file="${2:?--standard-prompt needs a file}"; shift 2 ;;
    --charts-prompt) charts_file="${2:?--charts-prompt needs a file}"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

work=$(mktemp -d "${TMPDIR:-/tmp}/jr-refresh.XXXXXX")
trap 'rm -rf "$work"' EXIT INT TERM

if [ -z "$standard_file" ] || [ -z "$charts_file" ]; then
  [ "$(uname -s)" = "Darwin" ] || { echo "the Swift dump needs macOS; pass --standard-prompt and --charts-prompt" >&2; exit 2; }
  pkg="$work/dump"
  mkdir -p "$pkg/Sources/dump"
  repo_name=$(basename "$root")
  cat >"$pkg/Package.swift" <<EOF
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
EOF
  cat >"$pkg/Sources/dump/main.swift" <<'EOF'
import Foundation
import JSONRenderCharts
import JSONRenderCore
import JSONRenderStandardCatalog

let directory = CommandLine.arguments[1]
try Catalog.standard.prompt().write(
    toFile: directory + "/standard.txt", atomically: true, encoding: .utf8)
try Catalog.charts.prompt().write(
    toFile: directory + "/charts.txt", atomically: true, encoding: .utf8)
EOF
  swift run --package-path "$pkg" dump "$work"
  standard_file="$work/standard.txt"
  charts_file="$work/charts.txt"
fi

# Splice: replace the block between the markers of $1 (label $2) with the AVAILABLE COMPONENTS
# section of prompt $3. Prints "stale" or "current" on stdout; writes unless $5 is 1. $4 is the
# expected component count.
splice() {
  python3 -I - "$1" "$2" "$3" "$4" "$5" <<'PY'
import re, sys

target, label, prompt_path, expected, check_only = sys.argv[1:6]
prompt = open(prompt_path, encoding="utf-8").read().split("\n")
start = next((i for i, l in enumerate(prompt) if l.startswith("AVAILABLE COMPONENTS")), None)
if start is None:
    sys.stderr.write(f"{prompt_path}: no AVAILABLE COMPONENTS section\n")
    sys.exit(3)
end = start + 1
while end < len(prompt) and prompt[end].strip() == "":
    end += 1
while end < len(prompt) and prompt[end].strip() != "":
    end += 1
section = prompt[start:end]
count = re.match(r"AVAILABLE COMPONENTS \((\d+)\)", section[0])
if not count or int(count.group(1)) != int(expected):
    sys.stderr.write(f"{label}: expected {expected} components, the prompt says {section[0]!r}; nothing written\n")
    sys.exit(3)
block = (
    f"<!-- BEGIN GENERATED: {label} -->\n"
    "<!-- Generated from Catalog.prompt() by skills/scripts/refresh-catalog-reference.sh. Do not edit by hand. -->\n\n"
    "```text\n" + "\n".join(section).rstrip("\n") + "\n```\n\n"
    f"<!-- END GENERATED: {label} -->"
)
text = open(target, encoding="utf-8").read()
pattern = re.compile(
    r"<!-- BEGIN GENERATED: " + re.escape(label) + r" -->.*?<!-- END GENERATED: " + re.escape(label) + r" -->",
    re.DOTALL,
)
if not pattern.search(text):
    sys.stderr.write(f"{target}: markers for {label} not found\n")
    sys.exit(2)
updated = pattern.sub(lambda _: block, text, count=1)
if updated == text:
    print("current")
else:
    print("stale")
    if check_only != "1":
        open(target, "w", encoding="utf-8").write(updated)
PY
}

status=0
for pair in "components:$refs/components.md:$standard_file:$expect_standard" \
            "charts:$refs/charts.md:$charts_file:$expect_charts"; do
  label=${pair%%:*}; rest=${pair#*:}
  target=${rest%%:*}; rest=${rest#*:}
  prompt_file=${rest%%:*}; expected=${rest#*:}
  result=$(splice "$target" "$label" "$prompt_file" "$expected" "$check") || exit $?
  echo "$label: $result"
  if [ "$check" = "1" ] && [ "$result" = "stale" ]; then status=1; fi
done
exit $status
