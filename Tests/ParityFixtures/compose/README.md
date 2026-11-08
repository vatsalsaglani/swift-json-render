# Compose fixtures

Recorded and hand-authored Decisions API responses for `JSONRenderComposeTests`. No test
calls the network; the tests replay these files through a recorded evaluator or an
injected `OpenAIDecisionsEvaluator.Transport`.

## What is real

- `probe-2026-11-07.response.json` is the only real network response. It is the body of
  one live `POST /v1/decisions` call (model `gpt-6-luna`, HTTP 200, 3.7 s, 429 input
  tokens) made on 2026-11-07 for the VPLAN 9.5 probe, copied byte for byte. It holds no
  key material: the probe saved only the response body.
- Every other `*.response.json` and `http.json` file is hand-authored in the Decisions wire
  shape (`{ model, answers[], usage }`, answers in question order, choice
  `probabilities[{value, probability}]`, score `probabilities[{value, label, probability}]`,
  `{ type: "refusal", name }`). The numbers are chosen to drive the composer, not measured.

No file here holds an API key, a real user's data, or a request body.

## Folders

Each scenario folder has a `case.json`: the candidate set (`candidates`, the folder that
holds `candidates.json`), the test catalog (`catalog`: `jev` or `dashboard`, built in
`Tests/JSONRenderComposeTests/Support/MinimalCatalog.swift`), the prompt, the initial state
and the expected outcome (`stopReason`, `requests`, `elements`, and optional `refused`,
`fallbacks`, `rootChildren`).

| Folder | Candidates | What it covers |
|---|---|---|
| `jev-preferences` | upstream `jev.mdx` example (3) | the full two-round path; `expected.spec.json` is the final spec |
| `dashboard-24` | 24 candidates, 3 resource groups, one repeated `Stack` (`maxUses: 3`) | question count below 100; named slots; nested stacks |
| `unavailable` | jev | an accepted `root: unavailable` ends with no spec after one request |
| `refusal-root` | jev | a refused root falls back to the first root candidate; a refused density uses `normal` |
| `low-confidence-order` | jev | a position below the confidence threshold keeps catalog order |
| `limit-density-sparse` | dashboard-24 | a `sparse` density caps the budget at 4 and stops with `limit` |
| `layout-cycle` | dashboard-24 | independently chosen parents form a cycle; the preview is kept with `limit` |
| `evaluator-429` | jev | an HTTP 429 through the real evaluator ends with `unavailable`; no body in the step |
| `wrong-answer-names` | jev | answers out of order end with `unavailable`; nothing is re-assigned by name |
