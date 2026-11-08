# Upstream parity fixtures

Contents: what the fixtures are, layout, the importer, the pin, what is read-only, sibling folders, conventions.

The Swift runtime is measured against json-render's own examples and tests, not against our reading of them. The fixtures live in `Tests/ParityFixtures/upstream/`. Read `Tests/ParityFixtures/README.md` for the case counts and the file shapes of every folder.

## The pin

- Upstream: https://github.com/vercel-labs/json-render, commit `18194121c8f087afacd9a8ef65fbda18374ee039` (v0.22.0, `@json-render/core` 0.22.0). Licence Apache-2.0, copied to `upstream/LICENSE-json-render`.
- `upstream/MANIFEST.json` records for every file: path, kind, upstream path and lines, commit, sha256, bytes, licence.
- Moving the pin is a coordinator decision. It means a new importer pin, regenerated fixtures, and a review of every changed expectation.

## Layout

| Folder | Cases | What it checks |
|---|---|---|
| `specs/` | 8 | The upstream example specs (decode, validate, render with no fallback) |
| `streams/` | 33 | SpecStream compile, compiler chunks, spec-patch, mixed text and fence |
| `validator/` | 45 | `validateSpec` issue codes, auto-fix |
| `state/` | 71 | RFC 6901 paths, set/add/remove, `__proto__` refusal, no holes past the array end |
| `actions/` | 27 | interpolate, resolve, param, execute |
| `expressions/` | 59 | `$state`, `$item`, `$index`, `$bindState`, `$bindItem`, `$cond`, `$computed`, `$template`, directives |
| `visibility/` | 76 | every operator, `not`, implicit AND, `$and`, `$or`, `$item`, `$index`, split for repeat |
| `validation/` | 124 | the 14 check types, helpers |
| `prompt/` | 3 files + `catalogs.json` | `Catalog.prompt()` byte for byte |
| `schema/` | 3 | `jsonSchema(strict:)` |

Each folder has an `index.json` with `{ name, kind, file or input/expected, upstreamTest }` rows. `upstreamTest` is `<file>:<line>` so a reviewer can jump to the upstream test.

## The importer

```
Scripts/import-fixtures.sh --check                    # offline: sha256, JSON, spec and size checks; exit 1 on drift
Scripts/import-fixtures.sh --source <clone>           # regenerate from a clone at the pinned commit
Scripts/import-fixtures.sh                            # shallow-clones the pinned commit itself
```

- It refuses any other commit. It writes only files whose sha256 changed. It needs `node` and `npm`.
- It installs the published `@json-render/*@0.22.0` packages in a temporary directory, never in the repository, and runs Node from a neutral directory.
- Run `--check` after any change near the fixtures. A drift is a stop.

## What is read-only

`Tests/ParityFixtures/upstream/**` is read-only after wave 0. Never edit a fixture to make a test pass. A failing parity test means the Swift code is wrong, or the upstream behaviour is a documented deviation: record the deviation in a comment at the code, in the test (a named exception), and in the handoff.

## Add fixtures

Put your own fixtures in a **sibling folder** of `upstream/`, with its own `index.json`:

- `Tests/ParityFixtures/streams/` for stream transcripts (out of order, root last, malformed line, object-mode fragments).
- `Tests/ParityFixtures/charts/` for chart specs.
- `Tests/ParityFixtures/skills/` (proposed; it does not exist yet) for the example specs in the "use" skill. Until then `FixtureRenderTests` (`Tests/JSONRenderSwiftUITests/Catalog/`) renders the eight upstream specs with no fallback block, and `skills/scripts/compile-examples.sh` builds every Swift block of the skills, so a renamed type fails a build.

Keep a small fixture folder under 64 KiB total and give every case a name and a one-line description. Add a count assertion to an inventory test so a wrong path cannot make a suite pass with zero cases.

## Conventions

- `"$undefined": true` stands for a JavaScript `undefined` (JSON has none). Map it to "key absent" / `nil`.
- `"$nan": true` stands for `NaN`.
- Paths without a leading slash are accepted, as upstream does.
- Upstream oddities are transcribed, not fixed. A Swift deviation is allowed only when the Swift behaviour is safer and documented (examples: a `visible` shape it cannot evaluate is hidden; `pushState` `$id` gives a UUID string; every action honours `confirm`).
- Sample strings (`secret123`, `Ada Lovelace`) come from upstream. No fixture holds a credential. Never add a real key, token or personal data.

## Parameterised suites

Parity suites use Swift Testing `@Test(arguments:)` over the `index.json` rows. Add a row and the case runs. A new fixture folder needs its loader (`ParityFixtures.cases(_:)` pattern) and an inventory count.
