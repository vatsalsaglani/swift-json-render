# Parity fixtures

Upstream material that the Swift runtime is measured against. It lets `JSONRenderCore`
and the streaming layer be tested against json-render's own examples and tests, not
against our reading of them.

- Upstream: <https://github.com/vercel-labs/json-render>
- Commit: `18194121c8f087afacd9a8ef65fbda18374ee039` (`1819412`, 2026-11-04, "chore(release): prepare v0.22.0")
- Package version: `@json-render/core` 0.22.0
- Licence: Apache-2.0, copied verbatim to `upstream/LICENSE-json-render`
  (`Copyright 2025 Vercel Inc.`)

JSON files cannot carry a licence header. This README and `upstream/MANIFEST.json` are
the attribution. `.txt` prompt files get no header: they must stay byte-exact for diffs.

Files under `upstream/` are read-only after wave 0; later waves add sibling folders.

## Regenerate and check

```
Scripts/import-fixtures.sh --source <path-to-clone>   # clone must be at the pinned commit
Scripts/import-fixtures.sh                            # shallow-clones the pinned commit itself
Scripts/import-fixtures.sh --check                    # offline: sha256, JSON, spec and size checks; exit 1 on drift
```

The script refuses any other commit. It writes only files whose sha256 changed
(a second run reports `written=0`). It needs `node` and `npm` and, without `--source`,
network access. It installs the published `@json-render/*@0.22.0` packages into a
temporary directory (never into the repository), runs Node only from a neutral
directory, and deletes the temporary directory on exit.

## How the fixtures were made

| Folder | Method |
|---|---|
| `specs/` | The `examples` array in `examples/no-ai/lib/examples.ts` is transpiled with TypeScript and imported. No `eval`, no copy by hand. Each `spec` is written as JSON. `null` prop values are kept. |
| `prompt/`, `schema/` | Produced by `catalog.prompt()` and `catalog.jsonSchema()` of the published 0.22.0 packages. Package versions and npm integrity strings are in `MANIFEST.json` under `generatedWith`. |
| all other folders | Upstream has no fixture files; the material is inline in `*.test.ts`. Each case is one upstream `it(...)` block, transcribed in `Scripts/fixtures/cases/*.mjs`. The importer runs every case against the published `@json-render/core` 0.22.0 and fails if a transcribed expectation differs. Where the transcription has no expectation (stream results, validator issue lists, auto-fix output) the value comes from that run. |

Every index row carries `upstreamTest` (`<file>:<line>`) so a reviewer can jump to the
source block. `MANIFEST.json` records for each file: `path`, `kind`, `upstreamPath`,
`upstreamLines`, `commit`, `sha256`, `bytes`, `licence`.

Two cases (`computed-unknown-function`, `computed-no-functions-in-context`) and one
validation case make upstream log a console warning. The importer silences it. It is
not part of the contract.

## Layout and file shapes

Case counts are in parentheses. Keys keep upstream order.

### `specs/` (8)
`<kebab-name>.json` holds the exact spec object. `index.json` is
`[{ name, description, file }]` in upstream order. The specs contain `null` props
(for example `description: null`); decoders must accept them.

### `streams/` (33)
- `<case>.jsonl` is the raw stream text, byte-exact. `<case>.expected.json` is
  `{ result, patches, initial? }` plus per kind:
  - `compile` (8): `compileSpecStream(input, initial)`.
  - `compiler` (7): `createSpecStreamCompiler`; `chunks` are the `push` inputs (their
    concatenation is the `.jsonl`), `pushes[i].newPatches` is the count returned by
    push `i`, `reset: true` means `reset()` ran before `getResult()`. `result` and
    `patches` come from `getResult()` and `getPatches()` at the end.
  - `spec-patch` (5): each line is applied with `applySpecPatch` to `initial`.
- `mixed/<case>.txt` is the input (concatenated chunks). `mixed/<case>.expected.json`
  is `{ chunks, flush, events }`, where `events` is the ordered list of
  `{ kind: "text" | "patch", value }`. `flush: true` means `flush()` was called at the end.
- `index.json` rows: `{ name, kind, input, expected, upstreamTest }`.

### `validator/` (45: 34 `validate`, 11 `autofix`)
- `<case>.spec.json` is the input spec; `<case>.expected.json` is
  `{ valid, codes, options: { checkOrphans }, issues, partial?, asserted?, counts? }`.
  `codes` is the sorted list of issue codes (duplicates kept). `issues` lists
  `{ code, severity, elementKey, message }` as upstream produced them; treat message
  text as informative, not as a contract, unless the test asserted it (the named-slot
  case asserts the substring `slot "header"`). `partial: true` means the upstream test
  asserts only the codes in `asserted` (and `counts`), not the full list.
- `autofix` cases: `{ autoFix: true, options, fixes, fixDetails, fixed, validAfterFix }`
  from `autoFixSpec`.
- All 13 issue codes are covered.

### `state/` (71)
`{ initial, ops, expected }`. `expected` is the final state. Op kinds:
`set`, `add`, `remove` (`path`, `value`), `get` (`path`, `expect`), `patch` (an RFC 6902
line in `patch`; `throws` names a required failure), `resolveRepeatStatePath`,
`resolveRepeatItemStatePath`, `flatten` (`flattenToPointers` of the current state),
`findFormValue`. Ops with `expect` assert their return value. Covers RFC 6901 `~0`/`~1`,
the `-` append, the `__proto__` refusal, and "no holes past the array end". The
`proto-pollution-refused` case ends with `{ "alias": { "polluted": true } }`: upstream
moves nothing for `/__proto__` and then creates `/alias/polluted`. The upstream test
asserts only that `Object.prototype` stays clean.

### `actions/` (27)
`kind` is one of: `interpolate` (`cases[]` of `{ state, input, expected }`), `resolve`
(`{ state, binding, expectedResolved }` from `resolveAction`), `param`
(`resolveActionParam`; `state`, repeat scope, `input`, `expected`), `execute`
(`executeAction` with a handler that `resolves` or `rejects`; `hooks` lists the optional
callbacks supplied besides `setState`; `expectedCalls` is the ordered call log
`{ fn, args }`; `expectThrows` is the rejection message when the error is not handled).

### `expressions/` (59)
`{ kind, state, repeatItem?, repeatIndex?, repeatBasePath?, functions?, directives?, input, expected }`.
`kind` is `value` (`resolvePropValue`), `props` (`resolveElementProps`) or `bindings`
(`resolveBindings`, result in `expectedBindings`). Covers `$state`, `$item`, `$index`,
`$bindState`, `$bindItem`, `$cond/$then/$else`, `$computed`, `$template` (absolute and
bare), nested objects and arrays, and custom directives.
- `functions` lists named `$computed` test functions: `fullName(args) = "${args.first} ${args.last}"`,
  `timestamp() = 1234567890`, `conditionalSum(args) = args.enabled ? args.x + args.y : 0`.
  `"functions": []` means a registry with no entries; an absent key means no registry.
- `directives` lists the custom directives registered for the case: `$double` resolves
  its operand and multiplies by 2; `$upper` resolves its operand and upper-cases
  `String(value)`.

### `visibility/` (76)
`kind` is `evaluate` (`{ state, repeatItem?, repeatIndex?, condition, expected }`) or
`split` (`splitRepeatVisibility`; `{ condition, expected: { container, itemFilter } }`).
Covers every operator, `{ $state }` operands, `not`, implicit AND, `$and`, `$or`,
`$item`, `$index`.

### `validation/` (124)
- `run` (107): `{ state, value, config, expected: { valid, errors, checks?, checkCount? } }`
  from `runValidation`. Every built-in assertion is a single-check config with message
  `"m"`. All 14 check names are covered, plus `enabled`, dynamic `$state` args, unknown
  functions (valid) and a custom function (`customFunctions: ["startsWithA"]`, which is
  `typeof v === "string" && v.startsWith("A")`).
- `helper` (17): `{ fn, args, expected }` for `check.<fn>(...args)`; `expected` holds the
  asserted keys only, and `partial: true` marks a result with more keys.
- `validateOn` has no upstream test in `validation.test.ts`, so no case exists.

### `prompt/`
- `shadcn-standalone.txt`: `catalog.prompt()` for the shadcn catalog (the React schema,
  `actions: {}`).
- `shadcn-inline.txt`: `catalog.prompt({ mode: "inline" })`.
- `minimal-two-components.txt`: a two-component catalog (`Card` with slots
  `default`/`header`/`footer`, `Text`).
- `catalogs.json`: the exact inputs: per component `description`, `slots`, `events` and
  `props` as JSON Schema of the zod object.

### `schema/`
`shadcn.strict.json`, `shadcn.loose.json`, `minimal-two-components.strict.json`:
`catalog.jsonSchema({ strict })`.

## Conventions

- `"$undefined": true` stands for a JavaScript `undefined` (JSON has none). It appears as
  an expected value, or as an input when the test passes `undefined`. Map it to "key
  absent / nil".
- `"$nan": true` stands for `NaN` (used by one `numeric` validation case).
- Paths without a leading slash are accepted by upstream (`setByPath(data, "user/name", ...)`);
  the fixtures record that as is. Upstream oddities are transcribed, not fixed.
- Sample strings such as `secret123` and `Ada Lovelace` come from upstream tests and
  examples. No fixture holds a credential.

## Size budget and current sizes

Budget (VPLAN 9.3): `upstream/` at most 1.5 MiB; no file above 256 KiB; the two shadcn
schema files are exempt from the per-file cap but must stay below 1 MiB each.

- Total: 558,199 bytes in 538 files (including `MANIFEST.json`).
- `schema/shadcn.strict.json`: 301 bytes. `schema/shadcn.loose.json`: 1,915 bytes.
  The strict schema is small because upstream emits `elements` with empty `properties`
  in strict mode; the loose schema carries the element `type` enum. Both are recorded as
  produced.
- `prompt/shadcn-standalone.txt`: 23,672 bytes. `prompt/shadcn-inline.txt`: 24,240 bytes.
  `prompt/catalogs.json`: 47,984 bytes.

## Not imported

Upstream tests that exercise only zod schema objects, React hooks, the AI SDK stream
transform (`createJsonRenderTransform`), the store subscription API (`createStateStore`:
notification counts, snapshot identity, structural sharing), `nestedToFlat`, the
`visibility.*` and `actionBinding.*` builder helpers, `defineDirective` and registry
errors, devtools, and the experimental compose and evaluator modules are not part of
these fixtures.
