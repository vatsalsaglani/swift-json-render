---
name: json-render-swift-update
description: Change the swift-json-render package itself by adding or changing a standard component, a chart, a directive, a $computed function, a theme token or preset, the catalog prompt or JSON Schema, parity fixtures and tests. Use when editing Sources, Tests or Examples of swift-json-render. It walks the artefact chain and the gates that keep spec semantics and upstream parity unchanged.
---

# swift-json-render: change the package

swift-json-render is a native Swift runtime for the json-render specification (https://github.com/vercel-labs/json-render). Its headline rule: **spectacularly simple by default, highly customisable in layers, and customisation never changes semantics.** This skill moves a change through every artefact in order and keeps the semantics-invariance suite and the upstream parity suites green.

This is not the skill for writing specs or wiring the package into an app. That is `json-render-swift-use`. Upstream's `codegen` skill (code generators) does not apply here; for skill format see upstream's `skill-creator`.

## Start

1. Read `AGENTS.md` (commands, module rules, build lock, test modes, worktrees, handoff). Its rules win over this file.
2. Read the plan: `docs/plan/vplan.mdx`; section 13A is the fan-out contract. Check single-owner files before you edit: `Package.swift`, the public API files listed in 13A.2, `README.md`, `CHANGELOG.md`, `NOTICE`, `AGENTS.md`, `docs/**`. A needed change there is a stop-and-report.
3. `git status --short --branch`. Do not touch unrelated work.
4. Decide the evidence before you code: which test fails first, which gate proves it.

## Modules

| Module | Rule |
|---|---|
| `JSONRenderCore` | Foundation only. Linux-capable. No SwiftUI, no network, no `URLSession` |
| `JSONRenderClient`, `JSONRenderMacros` | `@JRComponent`, `@JRProp`; Linux-capable |
| `JSONRenderSwiftUI` | Renderer, theme, registry, stream view. Apple only |
| `JSONRenderStandardCatalog` | The 36 components, directives, built-in actions |
| `JSONRenderCharts` | The 15 charts, chart tokens, aggregation functions |
| `JSONRenderRemoteImages` | The only target that fetches images |
| `JSONRenderCompose` | The only target that calls a Decisions API |

Specs never contain code: no `eval`, no JavaScript engine, no web view. Swift 6 language mode, strict concurrency, no `@unchecked Sendable`, no `nonisolated(unsafe)` without an approved comment.

## The artefact chain

Move in this order. Each step is a place a change can leave a gap.

| # | Artefact | Where | Reference |
|---|---|---|---|
| 1 | Contract: name, props, slots, events, limits | plan text | [add-component](references/add-component.md), [add-chart](references/add-chart.md) |
| 2 | Component or chart view + style protocol | `JSONRenderStandardCatalog/Components/`, `JSONRenderCharts/Components/` | same |
| 3 | Catalog entry (definition via `@JRComponent`) and registration line | `StandardEntries+GroupN.swift`, `ChartEntries+*.swift` | same |
| 4 | Prompt text | `Catalog.prompt()` (derived; check the diff) | [catalog-and-schema](references/catalog-and-schema.md) |
| 5 | JSON Schema | `Catalog.jsonSchema(strict:)` (derived; check the diff) | [catalog-and-schema](references/catalog-and-schema.md) |
| 6 | Theme token or preset value (the token struct is frozen) | `JSONRenderSwiftUI/Theme/` | [theme-tokens](references/theme-tokens.md) |
| 7 | Gallery page | `Examples/Gallery/` | [add-component](references/add-component.md) |
| 8 | Fixture spec, if semantics changed | `Tests/ParityFixtures/<sibling>/` | [parity](references/parity.md) |
| 9 | Tests | `Tests/<Target>Tests/` | [tests](references/tests.md) |
| 10 | Invariance suite entry | `Tests/JSONRenderSwiftUITests/Invariance/` | [tests](references/tests.md) |
| 11 | The use skill's references, regenerated and checked | `skills/` | [release](references/release.md) |
| 12 | A CHANGELOG line in the handoff (the coordinator owns the file) | handoff text | [release](references/release.md) |

Typical sizes: a new component touches steps 1 to 3, 7, 9 and 10 plus a line in 11; a prompt or schema change touches 4, 5, 9 and the parity fixtures; a new theme value touches 6, 9 and 10.

## What must never change

- Spec semantics: element shape, expressions, visibility, repeat scope, state path rules, the action binding shape.
- Upstream names: component names, prop names, event names, built-in action names, action param names. A spec written for the upstream shadcn catalog must keep rendering.
- Anything under `Tests/ParityFixtures/upstream/**` (read-only after wave 0). Never edit a fixture to pass a test.
- The prompt text for `includeExtensions: false`: it equals upstream byte for byte (`PromptParityTests`). Additions go on their own lines.
- The frozen files: `Theme/Tokens.swift` fields, `Registry/**`, `StreamTypes.swift`, `Package.swift`. A change is a coordinator change.
- The limits: 256 KiB, 2,000 elements, depth 64, 500 repeat rows, 64 KiB stream buffer. They may be lowered by a host, never raised.
- Customisation never changes semantics: a theme, a style hook, an override or a preset does not change state transitions or emitted actions. The invariance suite proves it.

## Code rules that recur

- Environment values hold `Equatable` structs (`JRRenderChild`, `JRBindingWriter`), never a bare closure.
- `Catalog.standard` and `Catalog.charts` are `static var ... { get throws(CatalogError) }`, nonisolated. `Catalog.register<C: View & JRComponentType>` is not `@MainActor`; the view is built inside the `@MainActor @Sendable` factory closure.
- `JRComponentType` is not `Sendable`.
- `ActionDispatcher.dispatch` returns `ActionSettleInfo.Outcome`; a loop over several bindings stops at `.cancelled`.
- `Catalog.autoFix(_:lossy:)` is the canonical form.
- A `pattern` check that the guard refuses reports `patternRefused`; show a neutral message, and run pattern checks on blur or submit.
- Recursion over spec data stays inside `SpecLimits.maxDepth` or is iterative. `JSONValue.maxDecodeDepth` is 64.
- Never iterate a `[String: JSONValue]` unsorted to produce output or ids.
- `nil` is undefined, `.null` is null. Do not conflate them.
- Never log or put into an issue message a prop value, state value, document text, diff, credential or request body. Ids, types, paths and counts only.
- Spawn no process, open no socket, read no file from core code.

## Gates

In this order; nothing may change a file after the parallel run:

```
./script/format.sh --fix
./script/format.sh --lint
./script/build.sh          # 0 warnings
./script/test.sh           # parallel, green
git commit
```

- Also: `Scripts/import-fixtures.sh --check` when fixtures could move; `swift build --target JSONRenderCore` for the Linux core; `skills/scripts/check-skills.sh` when a skill or an example changes; `swift build --package-path Examples/Gallery` when the Gallery changes.
- One SwiftPM invocation at a time per checkout. Run long work in the background with a time limit and a log file. Never write `while`/`until`/`sleep` wait loops.
- The advisor runs serial (`./script/test.sh --no-parallel`, what CI runs). Triage a failure by isolation, not by mode: [tests](references/tests.md).
- Bound the implementor and advisor loop to two verification rounds; a third round goes to the coordinator.
- In a worktree, after the gates are green and the commit is made: `rm -rf .build`. Never in the primary checkout.
- Do not push, tag, publish or open a pull request.

## Stop and report

- A needed change to `Package.swift`, a frozen file, a token field, a public API file in 13A.2, or `Tests/ParityFixtures/upstream/**`.
- A name the plan uses that the merged code does not have.
- A failing test in a file you do not own.
- A parity test that fails for a reason you cannot explain as a documented deviation.
- A secret, a key or a real person's data near the diff.

## Handoff

Report: delivered behaviour; changed paths; test counts and the commands run; evidence the checklist asks for; risks; the CHANGELOG line; notes for the documentor (reusable nuances: platform quirks, limits, decisions); the next dependency. Report to the user in ASD-STE100 Simplified Technical English, as `AGENTS.md` says.

## References

- [references/add-component.md](references/add-component.md): read when you add or change a standard component: contract, `@JRComponent`, style protocol, slots, events, accessibility, registration, tests.
- [references/add-chart.md](references/add-chart.md): read when you add or change a chart: data decoding, marks, limits, rules, accessibility, streaming domain, registration.
- [references/catalog-and-schema.md](references/catalog-and-schema.md): read when a change touches `PropSchema`, the prompt, the JSON Schema, a directive, a `$computed` function, an action, a validator or a rule.
- [references/theme-tokens.md](references/theme-tokens.md): read when a change needs a colour, size or font, a preset, contrast validation or chart tokens.
- [references/parity.md](references/parity.md): read when a change could move an upstream expectation, or you add fixtures.
- [references/tests.md](references/tests.md): read before you write tests, extend the invariance suite, or triage a failure.
- [references/release.md](references/release.md): read when you finish a change that needs a version, a changelog line, docs or a skills check.
