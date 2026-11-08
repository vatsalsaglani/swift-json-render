#!/usr/bin/env bash
# The link-level half of the network boundary: no object file of a non-network target may
# reference a networking symbol. (`Tests/JSONRenderCoreTests/NetworkBoundaryTests.swift` is the
# source-level half.) Run it after a build.
#
#   Scripts/check-network-symbols.sh [target ...]
#
# It finds the object files of each target in whatever layout the build system used
# (`.build/<triple>/debug/<Target>.build/` or `.build/out/Intermediates.noindex/…/<Target>-t.build/`).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

targets=("$@")
if [ "${#targets[@]}" -eq 0 ]; then
    targets=(JSONRenderCore JSONRenderSwiftUI JSONRenderStandardCatalog JSONRenderCharts JSONRenderClient)
fi

status=0
for target in "${targets[@]}"; do
    objects="$(find .build -type d \( -name "$target.build" -o -name "$target-t.build" \) \
        -exec find {} -name '*.o' \; 2>/dev/null | sort -u)"
    count="$(printf '%s\n' "$objects" | grep -c . || true)"
    if [ "$count" -eq 0 ]; then
        echo "check-network-symbols: no object files found for $target (build first)" >&2
        status=1
        continue
    fi
    if printf '%s\n' "$objects" | xargs nm -u 2>/dev/null \
        | grep -Eq 'URLSession|NWConnection|NSURLConnection'; then
        echo "check-network-symbols: network symbol in $target" >&2
        status=1
    else
        echo "check-network-symbols: $target ok ($count object files)"
    fi
done
exit "$status"
