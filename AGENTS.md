# swift-json-render agent guide

A native Swift runtime for the json-render specification
(https://github.com/vercel-labs/json-render). The plan is `docs/plan/vplan.mdx`
(VPLAN revision 4, 2026-11-07); its section 13A is the fan-out contract. Read
both before you start. The headline rule: **spectacularly simple by default,
highly customisable in layers; customisation never changes semantics.**

Report to the user in ASD-STE100 Simplified Technical English.

## Canonical commands

- Build: `./script/build.sh`
- Test, parallel: `./script/test.sh` (about 1 min at most at full size)
- Test, serial (the CI mode): `./script/test.sh --no-parallel`
- Format: `./script/format.sh --fix`, then `./script/format.sh --lint`
- Linux check for the core only: `swift build --target JSONRenderCore`

## Module rules

- `JSONRenderCore`: Foundation only. Linux-capable. No SwiftUI, no network, no
  `URLSession`.
- `JSONRenderRemoteImages` is the only target that fetches images.
  `JSONRenderCompose` is the only target that calls the Decisions API. A
  link-map test enforces this.
- Specs never contain code. No `eval`, no JavaScriptCore, no web view.
- Swift 6 language mode, strict concurrency. No `@unchecked Sendable`. No
  `nonisolated(unsafe)` without an advisor-approved comment.
- `Package.swift`, the public API files listed in VPLAN 13A.2, README,
  CHANGELOG and NOTICE have single owners. Do not edit them unless the
  wave table names you. A needed change is a stop-and-report.
- Upstream parity fixtures in `Tests/ParityFixtures/upstream/` are read-only
  after wave 0.
- Never put a secret, an API key, or a real user's data in a fixture, a test,
  a log or a commit.

## Build lock and waiting

SwiftPM serialises on `.build/.lock`. Run one SwiftPM invocation at a time per
checkout. The scripts call `script/await_build_lock.sh`, which clears only a
stale lock (no `lsof` holder and a dead recorded pid).

- Run long builds and tests as one background command. Never write
  `while`/`until`/`sleep` wait loops; the harness notifies on completion.
- Give every background test run a time limit (for example a sibling
  `sleep 360` watchdog that kills it and prints TIMEOUT). A hung async test
  otherwise waits for ever.
- Never pipe `swift test` through `grep`/`tail`; redirect to a log file.

## Tests

- Swift Testing for new tests. Await async APIs; no fixed sleeps.
- The implementor's final order: `format --fix` → `format --lint` → build →
  parallel tests → commit. Nothing changes a file after the parallel run.
- The advisor runs serial (and parallel when the change touches concurrency).
- Triage a failure by running the single test alone:
  `swift test --filter "<exact name>"`. Alone fails → real bug. Passes alone and
  serially → load; note it. Passes alone, fails serially → order dependence;
  fix it.

## Worktrees

- One worktree per agent under `.claude/worktrees/<agent>-<name>`.
- As your final step, after gates are green and commits are made:
  `rm -rf .build` in your worktree. Never in the primary checkout.
- Do not push, tag, or open a pull request; the coordinator does that.

## Handoff

Report: delivered behaviour, changed paths, test counts and commands, evidence
the exit checklist asks for, risks, notes for the documentor, and the next
dependency.
