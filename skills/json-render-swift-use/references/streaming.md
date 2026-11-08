# Streaming

Contents: the line format, the order to write in, chat streams, object mode, edits, what the app sees, budgets, the app side.

A model can send a spec as it writes it. Each line is one JSON Patch (RFC 6902) operation that builds the spec. The view draws at most once per display frame, so a fast stream does not cost more frames.

## JSONL patch lines

```jsonl
{"op":"add","path":"/root","value":"card"}
{"op":"add","path":"/elements/card","value":{"type":"Card","props":{"title":"Open tasks"},"children":["list"]}}
{"op":"add","path":"/elements/list","value":{"type":"Stack","props":{},"repeat":{"statePath":"/tasks","key":"id"},"children":["task"]}}
{"op":"add","path":"/state/tasks","value":[]}
{"op":"add","path":"/state/tasks/0","value":{"id":"1","title":"Write the spec","done":false}}
```

- One JSON object per line, no markdown, no code fence, no blank-line separators needed.
- Operations: `add`, `remove`, `replace`, `move` and `copy` (need `from`), `test`. `add` is the common one; `add` on an object key creates or replaces it.
- Paths are JSON Pointers into the spec: `/root`, `/elements/<id>`, `/elements/<id>/props/title`, `/state/<path>`.
- `-` as the last token appends: `{"op":"add","path":"/state/tasks/-","value":{...}}`. A chart can grow with `/elements/c1/props/data/-`.
- A line that is not a patch is written to the journal and skipped. The stream goes on.
- A path with `__proto__` is refused. A `test` that fails is journaled and later lines still apply.

Full example: `examples/stream.jsonl`.

## Order

1. `/root` first. Without it the view shows one card skeleton.
2. Then elements, parents before children when you can. A child that has not arrived yet is a skeleton, and an out-of-order child is kept until its parent arrives, so order is a quality choice, not a correctness one.
3. `/state` patches right after the elements that read them. One patch per array item (`/state/tasks/0`, `/state/tasks/1`), not one big array, so the list fills in row by row. Create the array first (`"value": []`).
4. Every element has `type`, `props` and `children`. Leaves use `"children": []`.
5. Do not leave a dangling child id at the end. On finish the view validates the spec and prunes ids that point at no element, but the branch is lost.

When the stream ends, the final spec is validated. A `missing_child` or similar issue is reported to the app (`onFinish`); it never crashes the view.

## Chat streams: the spec fence

For a chat answer, use the mixed mode: write prose, then the patches inside a `spec` fence.

````text
Here is a small task list.

```spec
{"op":"add","path":"/root","value":"card"}
{"op":"add","path":"/elements/card","value":{"type":"Card","props":{"title":"Tasks"},"children":[]}}
```

Tick a task to finish it.
````

- Outside the fence, a line is prose (shown as text). A line that is a valid patch is also taken as a patch, but put patches in the fence to be sure.
- A JSON line with a string `op` that is not a valid patch (an unknown `op`, no `path`) is a bad patch, not prose: it goes to the journal as `badLine`, inside or outside the fence.
- Inside the fence, other lines that are not patches are dropped without a journal entry.
- Fence lines are not shown. Blank lines are skipped.

Full example: `examples/chat-fence.txt`.

## Object mode: one JSON document in pieces

A function call or tool call delivers the whole spec as one JSON object, in argument fragments (for example the `show_view` tool of a voice agent). Object mode reads the growing text with a tolerant parser: it closes open strings, arrays and objects, and drops a trailing partial token. It emits patches at the level of `/root`, `/state` and `/elements/<id>` (one patch per changed element, whole). An element without a `type` yet is held back.

When writing for object mode: put `root` first, then `elements` in tree order, then `state`; keep keys short. Bytes that no continuation can make valid JSON stop the stream at once (`unrecoverable`, "invalid JSON"); the last good snapshot stays. At the end the strict parse decides; an unclosed document is journaled (`badLine`, "document was not closed") and the tolerant result is used.

## Edit an existing spec

To change a spec, send patches against it. `UserPrompt.build(prompt:currentSpec:state:editModes:)` builds the user message; `PromptOptions.editModes` adds the instructions.

```swift
import JSONRenderCore

func editMessage(_ request: String, current: Spec, state: JSONValue) -> String {
    UserPrompt.build(
        prompt: request, currentSpec: current, state: state, editModes: [.patch])
}
```

- Patch mode (RFC 6902) is supported: `replace` an element, `remove` one, `add` a new one.
- Merge (RFC 7396) and diff edit modes are not supported in 0.22.x. Do not ask for them.

## What the app sees

| Concept | Meaning |
|---|---|
| `SpecSnapshot` | One committed state: `version`, `spec`, `plan`, `dangling`, `isFinal`, `journal` |
| `dangling` | Ids that a parent lists but no patch has defined yet; they draw as skeletons |
| `journal` | Stream problems: `badLine`, `patchFailed`, `unrecoverable`, `budget`. Ids, ops and paths only, never values |
| phase | `idle`, `streaming`, `stopped`, `final` |

Cancel keeps the last snapshot (`stopped`). A stream that throws also ends `stopped` and journals `unrecoverable` with the error type name only. A budget breach freezes the stream at the last good snapshot. Running a `StreamModel` again after it ended starts from its initial spec and state.

```swift
import Foundation
import JSONRenderCore

func readLine(_ line: String) throws -> SpecPatch {
    try JSONDecoder().decode(SpecPatch.self, from: Data(line.utf8))
}
```

## Budgets

| Budget | Value |
|---|---|
| Spec size | 256 KiB (an estimate kept while streaming) |
| Elements | 2,000 |
| Nesting depth | 64 |
| Stream buffer | 64 KiB for one partial line |

## The app side

```swift
import JSONRender
import SwiftUI

struct AssistantView: View {
    let lines: AsyncThrowingStream<String, any Error>
    let catalog: Catalog

    var body: some View {
        JSONRenderStreamView(stream: lines, mode: .jsonl, catalog: catalog)
    }
}
```

`JSONRenderStreamView(stream:mode:catalog:host:limits:observer:onFinish:)` runs the whole pipeline: decode, patch, snapshot, coalesce, draw with `JSONRenderView`. `mode` is `.jsonl`, `.object` or `.mixed`. Pass a trailing closure `{ snapshot, store in ... }` (with `limits:` and `onFinish:`) to draw the snapshot yourself. A host that owns the lifetime creates a `StreamModel` and passes it with `JSONRenderStreamView(model:catalog:host:observer:)` or `JSONRenderStreamView(model:content:)`, and feeds it with `model.run(_:mode:onFinish:)` (an `AsyncThrowingStream<String, any Error>` or any sendable `AsyncSequence` of `String`) or `model.run(bytes:mode:onFinish:)` (UTF-8 chunks). Lower-level pieces for tests or custom hosts: `SpecStreamDecoder(mode:)` with `push(_:)` and `flush()` returning `SpecStreamEvent`s, and `SpecStore` (an actor) with `apply(_:)`, `finish()` and `cancel()`.

While streaming, the stream's `/state` wins over the live state model; after `finish` the store belongs to the user.

Streaming rules also carry to charts: the y-domain only grows during a stream and settles once at the end; series keep first-appearance order.
