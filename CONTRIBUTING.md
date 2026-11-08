# Contributing

Thank you for helping. This file says how to build, test and change swift-json-render. The headline rule: **spectacularly simple by default, highly customisable in layers; customisation never changes semantics.**

## Build, test, format

```sh
./script/build.sh                  # swift build (waits for a stale build lock)
./script/test.sh                   # tests, parallel (about a minute)
./script/test.sh --no-parallel     # tests, serial: this is what CI runs as the release gate
./script/format.sh --fix           # then
./script/format.sh --lint          # swift format, strict
swift build --target JSONRenderCore    # the platform-neutral core, as on Linux
```

The package needs Swift 6.2 tools, and its targets build in Swift 6 language mode with strict concurrency. `JSONRenderCore` uses Foundation only.

Run one SwiftPM command at a time per checkout: a second one waits silently on `.build/.lock`. The scripts call `script/await_build_lock.sh`, which clears only a stale lock.

## The two test modes

Parallel finds concurrency bugs. Serial finds order dependence between tests, and it is what CI runs. Run parallel while you work and serial before you ask for review. If a test fails in one mode, run that test alone (`swift test --filter "<name>"`):

| Alone | Serial | Meaning |
|---|---|---|
| fails | fails | A real bug. Fix it |
| passes | passes | Load on the machine. Note it and change nothing |
| passes | fails | Order dependence. Fix it, because CI runs serial |
| fails | passes | A real concurrency bug that only parallel finds. Fix it |

## Rules for changes

- **Spec changes follow upstream.** A change to the spec, an expression, a prop or a prompt line comes from a new json-render release and a new fixture pin. Files under `Tests/ParityFixtures/upstream/` are read-only; add your own cases in a sibling folder.
- **A component pull request** adds its Gallery page, a style protocol, VoiceOver labels and a prompt test, and passes the contrast check in all presets.
- **No new dependency** without an issue that says why. The package depends on swift-syntax (the macro) and, for documentation builds only, swift-docc-plugin.
- **Customisation never changes semantics.** The invariance suite proves that themes, styles and replacement views give the same state changes and the same actions for every example spec.
- **No network outside two targets.** Only `JSONRenderCompose` and `JSONRenderRemoteImages` may use networking, and a test and a CI step enforce it.
- **No secrets.** Never put a key, a token or real personal data in a fixture, a test, a log or a commit. Logs hold ids, paths and counts, never prop or state values.
- No `@unchecked Sendable`, and no `nonisolated(unsafe)` without a written reason.

## Fixtures

```sh
Scripts/import-fixtures.sh --check              # offline: sha256, shape and size checks
Scripts/import-fixtures.sh --source <clone>     # regenerate from a clone at the pinned commit
Scripts/parity-report.sh                        # run the parity suites and rewrite docs/parity.md
```

`--check` reports any drift in `upstream/`. Run the parity report after a fixture or parity test change and commit `docs/parity.md`; CI regenerates it and fails if it differs (the generation comment is ignored).

## Skills

The two skills live in `skills/`. `.claude/skills/json-render-swift-update` is a symlink to the update skill, so a clone has it ready; keep it a symlink.

```sh
skills/scripts/refresh-catalog-reference.sh     # rewrite the generated component and chart lists from the code
skills/scripts/check-skills.sh                  # frontmatter, names, links, examples, symlink
skills/scripts/compile-examples.sh              # build every Swift block of the skills, README and DocC articles
```

When a public name, a prop, a limit or a default changes, change the matching skill reference in the same commit.

## The showcase site

`site/` is a static site with live previews. Its data pipeline: `site/tools/dump-catalog.sh` writes `site/data/catalog.generated.json` from the real Swift catalogs; `node site/tools/merge-catalog.mjs` replaces the description, props, events and slots of every standard and chart entry (the hand-written examples stay); `node site/tools/sync-data.mjs` writes `site/data/components.js`; `node site/tests/check.mjs` is the gate. Run all four after a catalog change.

## Documentation

The DocC catalog is `Sources/JSONRenderCore/Documentation.docc/`. A symbol link must name a symbol that exists. Build it with the command in the README. Notes on platform quirks and decisions go in `docs/notes/` (see its index).

## Commits

Write an imperative subject and make one change per commit, for example "Table: cap literal rows at 500". Say what the user sees. Do not tag, push or open a release as part of a change; the maintainer does that.

## Code of conduct

To be chosen by the maintainer.
