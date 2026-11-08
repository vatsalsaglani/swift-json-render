#!/usr/bin/env bash
# Runs the parity suites and writes docs/parity.md from their results.
#
#   Scripts/parity-report.sh           # needs macOS or Linux with the Swift toolchain, and python3
#
# CI runs it in the serial macOS leg and then checks that nothing changed except the
# generation comment:  git diff -I '^<!-- generated' --exit-code -- docs/parity.md
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

./script/await_build_lock.sh

tmp="$(mktemp -d "${TMPDIR:-/tmp}/jr-parity.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

# Swift Testing writes `<name>-swift-testing.xml` next to the requested file name.
# The filter names the suites that read Tests/ParityFixtures (type names, not display names).
swift test --filter 'Parity|FixtureInventory|ChartFixture|CompositeFixture' \
    --xunit-output "$tmp/parity.xml" > "$tmp/test.log" 2>&1 || {
    cat "$tmp/test.log" >&2
    echo "parity-report: the parity suites failed; docs/parity.md is not updated." >&2
    exit 1
}

toolchain="$(swift --version 2>&1 | head -n 1)"
python3 -I -B Scripts/parity/render.py "$tmp" Tests/ParityFixtures/upstream/MANIFEST.json "$toolchain" \
    > "$tmp/parity.md"
mkdir -p docs
cp "$tmp/parity.md" docs/parity.md
echo "wrote docs/parity.md"
