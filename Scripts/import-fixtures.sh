#!/usr/bin/env bash
# Import the upstream parity fixtures for swift-json-render.
#
#   Scripts/import-fixtures.sh [--source <clone> | --url <git url>] [--commit <sha>] [--out <dir>] [--check]
#
# Pinned to vercel-labs/json-render 1819412 (v0.22.0). Writes only files whose sha256 changed.
# --check runs the offline shape/size/sha256 checks on --out and exits 1 on drift; it writes nothing.
set -euo pipefail

PINNED_COMMIT="18194121c8f087afacd9a8ef65fbda18374ee039"
DEFAULT_URL="https://github.com/vercel-labs/json-render.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HELPERS="$SCRIPT_DIR/fixtures"

source_dir=""
url="$DEFAULT_URL"
commit="$PINNED_COMMIT"
out="$REPO_ROOT/Tests/ParityFixtures/upstream"
check_only=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) source_dir="${2:?--source needs a path}"; shift 2 ;;
    --url) url="${2:?--url needs a value}"; shift 2 ;;
    --commit) commit="${2:?--commit needs a sha}"; shift 2 ;;
    --out) out="${2:?--out needs a path}"; shift 2 ;;
    --check) check_only=1; shift ;;
    -h|--help) sed -n '2,8p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

command -v node >/dev/null 2>&1 || { echo "node is required" >&2; exit 2; }

if [ "$commit" != "$PINNED_COMMIT" ]; then
  echo "refusing commit $commit; this importer is pinned to $PINNED_COMMIT" >&2
  exit 1
fi

# Run Node from a neutral directory, never from the clone or the fixtures directory.
cd /

if [ "$check_only" -eq 1 ]; then
  if [ -n "$source_dir" ]; then
    node "$HELPERS/check.mjs" "$out" "$source_dir"
  else
    node "$HELPERS/check.mjs" "$out"
  fi
  exit 0
fi

tmp="$(mktemp -d "${TMPDIR:-/tmp}/jr-fixtures.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

if [ -z "$source_dir" ]; then
  git clone --quiet --filter=blob:none --no-checkout "$url" "$tmp/clone"
  git -C "$tmp/clone" checkout --quiet "$commit"
  source_dir="$tmp/clone"
fi

head_sha="$(git -C "$source_dir" rev-parse HEAD)"
if [ "$head_sha" != "$PINNED_COMMIT" ]; then
  echo "source is at   $head_sha" >&2
  echo "importer pin   $PINNED_COMMIT" >&2
  exit 1
fi

# Published packages used for catalog.prompt() / jsonSchema() and for TypeScript transpiling.
mkdir -p "$tmp/npm" "$tmp/stage"
npm install --no-save --no-audit --no-fund --silent --prefix "$tmp/npm" \
  typescript@5 @json-render/core@0.22.0 @json-render/react@0.22.0 @json-render/shadcn@0.22.0 \
  zod@4 react@19 react-dom@19 >"$tmp/npm.log" 2>&1 || { cat "$tmp/npm.log" >&2; echo "npm install failed" >&2; exit 1; }

node "$HELPERS/extract-specs.mjs" "$source_dir" "$tmp/stage" "$tmp/npm"
node "$HELPERS/capture-prompt-and-schema.mjs" "$tmp/stage" "$tmp/npm"
node "$HELPERS/build-cases.mjs" "$source_dir" "$tmp/stage" "$tmp/npm"
node "$HELPERS/finalize.mjs" "$tmp/stage" "$source_dir" "$commit"

mkdir -p "$out"
node "$HELPERS/sync.mjs" "$tmp/stage" "$out"
node "$HELPERS/check.mjs" "$out" "$source_dir"
