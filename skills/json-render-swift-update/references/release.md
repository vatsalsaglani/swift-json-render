# Release

Contents: versions, changelog, docs, skills, who tags.

## Versions

The package tracks upstream json-render by minor: `0.22.x` follows upstream 0.22. Pre-release tags are `0.22.0-alpha.N`. The tag `0.22.0-alpha.0` marks wave 1 (core). A release moves to the next upstream minor only with new fixtures and a new importer pin (`parity.md`).

Rules for the version number:

- Patch: bug fixes and text fixes that do not move a prompt fixture line.
- Minor: new components, props, charts, directives, rules; prompt text additions. Nothing removed.
- A removal or rename of an upstream name, a prop, a param or an expression changes semantics. It is not allowed inside a minor.

## Changelog

`CHANGELOG.md` (Keep a Changelog) has one owner: the coordinator. An agent does not edit it; the handoff carries a **CHANGELOG line** for each change, in this shape: `Added|Changed|Fixed|Deprecated: <what a user sees> (<component or area>)`. Name any prompt text change, any new validator rule, and any new public type. Each release section names the upstream json-render commit it implements.

## Docs

- DocC for the public API: every public type and method has a doc comment that says what it does, what it throws, and what it never logs. The catalog is `Sources/JSONRenderCore/Documentation.docc/` (ten articles); build it with `swift package generate-documentation --target JSONRenderCore` (the CI `docc` job builds all seven library targets as one combined archive). A symbol link in an article must name a symbol that exists.
- The README, `NOTICE`, `AGENTS.md` and `docs/**` have single owners; a needed edit is a request to the coordinator.
- A reusable nuance (a platform quirk, a limit, a decision) goes into a reference note or a decision record in the same change; the coordinator or documentor owns the files under `docs/`.

## The skills

- Both skills live in `skills/`. `skills/scripts/check-skills.sh` validates them: frontmatter, names equal folders, body length, links, examples decode. Run it after every skill edit.
- `.claude/skills/json-render-swift-update` is a symlink to `skills/json-render-swift-update`, so a clone has the update skill ready. Keep it a symlink.
- At release, run `skills/scripts/refresh-catalog-reference.sh` so the component and chart lists match the code, then `skills/scripts/check-skills.sh` and `skills/scripts/compile-examples.sh` (builds every Swift block of both skills against this checkout; a block that cannot build outside a module starts with `// not compiled: <reason>`).
- Install check: `npx skills add vatsalsaglani/swift-json-render --skill json-render-swift-use` and `--skill json-render-swift-update` into a scratch project; open the installed `SKILL.md` and follow one link.
- The use skill must stay correct: when a public name, a prop, a limit or a default changes, change the matching reference in the same commit.

## CI, the parity report and the site data

- `.github/workflows/ci.yml` runs on a push to `main` or `jr/**`, on a pull request and on demand: `format`, `macos` (a parallel and a serial leg), `linux` and `docc`. The serial macOS leg also builds the Gallery and its snapshots, runs the skills and site checks, and checks that `docs/parity.md` is current.
- `Scripts/parity-report.sh` runs the parity suites and writes `docs/parity.md` (counts per fixture folder, the pinned upstream commit, what is not upstream). Run it after any fixture or parity test change and commit the result.
- Site data: `site/tools/dump-catalog.sh` (writes `site/data/catalog.generated.json` from the real catalogs) → `node site/tools/merge-catalog.mjs` (replaces description, props, events and slots; keeps the hand-written examples) → `node site/tools/sync-data.mjs` → `node site/tests/check.mjs`. A catalog change needs all four.

## Tagging and publishing

Tagging, pushing, creating a pull request and publishing a release are the coordinator's and the user's actions. An agent does not tag, push or publish. As a last step in a worktree, after the gates pass and the commit is made: `rm -rf .build`.
