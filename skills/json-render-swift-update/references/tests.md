# Tests, invariance and the gates

Contents: layout per target, parity suites, the invariance suite, Linux core, test modes, triage, grep gates.

## Layout

Swift Testing everywhere (`@Suite`, `@Test`, `#expect`). Await async APIs; no fixed sleeps. Never log or assert on private data.

| Target | Tests | Covers |
|---|---|---|
| `JSONRenderCoreTests` | `Tests/JSONRenderCoreTests/` | spec decode, expressions, visibility, actions, state, validation, validator, catalog, prompt, schema, parity suites; `Stream/` for the stream layer |
| `JSONRenderMacroTests` | `Tests/JSONRenderMacroTests/` | `@JRComponent` and `@JRProp` expansion and diagnostics |
| `JSONRenderSwiftUITests` | `Tests/JSONRenderSwiftUITests/` | theme, element resolution (pure), render model, slots, directives, components, invariance; `Stream/`, `Inputs/` |
| `JSONRenderChartsTests` | `Tests/JSONRenderChartsTests/` | chart data, formats, LTTB, monotonic domain, rules, functions, definitions, `Composite/` |

Support code: `Tests/JSONRenderCoreTests/Support/` (fixture loader, shadcn catalog fixture, recording hosts and observers).

Rules for a new test:

- Put pure logic behind a function with no UI import and test that. Avoid view-tree tests; use the model layer.
- One behaviour per test, named for the behaviour. A bug fix comes with a regression test.
- Parameterise over `index.json` rows for fixture-driven suites.
- Seeded random inputs use a fixed generator and print the seed on failure.
- Do not rely on dictionary order. Sort before you compare.

## The invariance suite

`Tests/JSONRenderSwiftUITests/Invariance/` proves that customisation never changes semantics. Headless, through the model layer, no views: for each of the eight fixture specs and each scripted interaction (`(elementID, event, payload)` and direct `store.set` writes, defined per fixture in `Invariance/Scripts.swift`), run the render model with (a) `Catalog.standard` and `.native`, (b) `.highContrast`, (c) every standard type replaced by a stub that renders `EmptyView`. Record the sequence of state changes and the dispatched actions. Assert (a) equals (b) equals (c). Also assert the resolved props and bindings handed to the stub equal those handed to the real view.

To extend it:

1. A new component that emits events or binds state: add an interaction for it to the script of the fixture that uses it, or add a small fixture.
2. A new preset: add it to the list of themes in the suite.
3. A new style hook or override point: add a variant (c)-style run for it.
4. The suite must stay green with no edit to expected sequences. If the sequence changes, the change altered semantics: fix the code, not the suite.

## Linux core job

The platform-neutral products (`JSONRenderCore`, `JSONRenderClient`, `JSONRenderCompose`, the macros) must build on Linux. Check: `swift build --target JSONRenderCore`. Core stays Foundation only: no SwiftUI, no network, no `URLSession`. `Tests/JSONRenderCoreTests/NetworkBoundaryTests.swift` enforces the link map at source level (only `JSONRenderCompose` and `JSONRenderRemoteImages` may name a network API), and CI adds an object-file `nm` check for the same rule.

## Test modes

| Mode | Command | Use |
|---|---|---|
| Parallel | `./script/test.sh` (about 1 min at most) | While iterating. The only mode where concurrency bugs show |
| Serial | `./script/test.sh --no-parallel` | What CI runs. The only mode that finds order dependence |

CI injects flags with `JR_TEST_FLAGS` (for example `--no-parallel`).

Final order, with nothing changing a file after the parallel run:

```
./script/format.sh --fix
./script/format.sh --lint
./script/build.sh          # 0 warnings
./script/test.sh           # parallel, green
git commit
```

One SwiftPM invocation at a time per checkout; run builds and tests in the background with a time limit and redirect output to a log file (never pipe `swift test` through `grep` or `tail`). If a build looks hung, run `script/await_build_lock.sh`.

## Triage a failing test by isolation

Re-run the single test alone (`swift test --filter "<exact name>"`).

| Alone | Serial | Verdict |
|---|---|---|
| fails | fails | Real bug. Fix it |
| passes | passes | Scheduler starvation under load. Note it; change nothing |
| passes | fails | Order dependence. Must fix (CI runs serial) |
| fails | passes | A real concurrency bug that only parallel finds |

Never edit a test you do not own to make a gate pass. A failure in a file owned by another agent is a stop-and-report.

## Grep gates (run before a commit)

- No `@unchecked Sendable` and no `nonisolated(unsafe)` (without an approved comment) in `Sources/`.
- No `import JSONRenderStandardCatalog` in `Sources/JSONRenderCharts`.
- `AnyView(` only at the registry boundary and in style configurations.
- No `URLSession` outside `JSONRenderRemoteImages` and `JSONRenderCompose`.
- No secret, key, token or user-home path in the diff.
