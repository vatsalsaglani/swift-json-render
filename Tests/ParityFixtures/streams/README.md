# Own stream fixtures (jr-2)

Swift-only stream transcripts, a sibling of `upstream/streams/` (which stays read-only).
`index.json` rows are `{ name, input, expect }`:

- `*.jsonl`: replayed one line per commit into `SpecStore` (`SpecStoreTests`) and split at
  every byte offset (`ChunkBoundaryFuzzTests`). `expect` holds `rootID`, the final plan
  `order`, the `journal` size, and optionally `danglingAfter` (line index → dangling ids
  after that line), `badLines` (journaled line indexes) and `dataCount`.
- `object-mode-fragments.json`: `{ fragments, expected }`, one spec document cut into seven
  pieces for `.object` mode (`ObjectModeTests`).

No secrets, no real user data. Keep the folder under 64 KiB.
