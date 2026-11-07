#!/bin/sh
# Checks both skills: frontmatter, name = folder, body length, links resolve, examples decode,
# no secret, and the symlink that pre-installs the update skill. Run it after any skill edit.
#
#   skills/scripts/check-skills.sh
#
# Needs python3 (standard library only). It runs from the repository root.
set -eu

root=$(cd "$(dirname "$0")/../.." && pwd)
cd "$root"

for name in json-render-swift-use json-render-swift-update; do
  python3 -I "$root/skills/scripts/quick_validate.py" "skills/$name"
done

link=".claude/skills/json-render-swift-update"
[ -L "$link" ] || { echo "missing symlink: $link" >&2; exit 1; }
[ "$(cd "$link" && pwd -P)" = "$(cd skills/json-render-swift-update && pwd -P)" ] \
  || { echo "$link does not point at skills/json-render-swift-update" >&2; exit 1; }

sh -n skills/scripts/refresh-catalog-reference.sh
sh -n skills/scripts/check-skills.sh
echo "skills ok"
