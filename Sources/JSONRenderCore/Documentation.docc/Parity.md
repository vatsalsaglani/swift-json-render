# Parity with json-render

The runtime is measured against upstream's own tests, not against our reading of them.

## What the fixtures are

`Tests/ParityFixtures/upstream/` holds material copied from json-render at a pinned commit:

- Upstream: <https://github.com/vercel-labs/json-render>, release v0.22.0
- Commit: `18194121c8f087afacd9a8ef65fbda18374ee039` (`1819412`)
- Licence: Apache-2.0, kept as `upstream/LICENSE-json-render`

Upstream has no fixture files. Each case is one upstream `it(...)` block, transcribed in `Scripts/fixtures/cases/*.mjs`. The importer runs every case against the published `@json-render/core` 0.22.0 and fails if a transcribed expectation differs. The prompt and schema files come from `catalog.prompt()` and `catalog.jsonSchema()` of the published packages, and the eight example specs from upstream's `examples` array.

The files under `upstream/` are read-only. `MANIFEST.json` records the path, the sha256 and the upstream source of each one, and `Scripts/import-fixtures.sh --check` verifies them offline. A failing parity test means the Swift code is wrong, or the difference is a documented deviation.

## The report

`docs/parity.md` is generated, not written. `Scripts/parity-report.sh` runs the parity suites with `swift test --xunit-output`, reads the Swift Testing result file, counts the cases in each fixture folder and writes one table row per folder with its result. CI regenerates it in the serial macOS job and fails if it changed (the generation comment is ignored). A parameterised test is one test function that runs every case; `FixtureInventoryTests` guards each case count so a wrong path cannot pass with zero cases.

## What is not upstream

The package adds a few things on purpose. None changes the meaning of a spec that upstream accepts.

- Two built-in actions, `toggleState` and `incrementState`. `PromptOptions(includeExtensions: false)` removes them from the prompt, for a spec that must also run on the web.
- Optional extra props (the `+` props), such as `Card.variant` and `Table.sortable`. The prompt line of each standard component equals upstream's after the extras are removed.
- Extra slots, the 15 charts, the display-link streaming layer, the style and theme layers, and the composer.
- Safer behaviour where upstream is loose: a `visible` shape the runtime cannot evaluate is hidden, and a regular expression that could take exponential time is refused with a neutral message.

Upstream tests of zod schemas, React hooks, the AI SDK transform, the devtools and the experimental compose modules are not imported.
