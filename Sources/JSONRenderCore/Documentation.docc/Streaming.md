# Streaming

A model can send a spec while it writes it. The view fills in as the lines arrive.

## Three modes

``SpecStreamDecoder`` turns streamed text into events. The mode says what the text is.

| Mode | The text is | Notes |
|---|---|---|
| `.jsonl` | One JSON Patch (RFC 6902) operation per line | A line that is not a patch is journaled as a bad line and skipped |
| `.mixed` | Chat prose with the patches inside a `spec` fence | Prose is `.text`. A JSON line with an unknown `op` is a bad patch, not prose |
| `.object` | One JSON document that arrives in fragments, such as tool-call arguments | A tolerant parser closes open strings and objects. It emits `/root`, `/state` and each finished element |

In object mode, bytes that no later text can make valid JSON stop the stream at once. In every mode the decoder reports a fixed vocabulary of reasons and never reports stream text.

```jsonl
{"op":"add","path":"/root","value":"card"}
{"op":"add","path":"/elements/card","value":{"type":"Card","props":{"title":"Tasks"},"children":[]}}
```

## One call

`JSONRenderStreamView` runs the whole pipeline: decode, patch, snapshot, coalesce, draw.

```swift
import JSONRender
import SwiftUI

struct Assistant: View {
    let lines: AsyncThrowingStream<String, any Error>

    var body: some View {
        if let catalog = try? Catalog.standard {
            JSONRenderStreamView(stream: lines, mode: .jsonl, catalog: catalog)
        }
    }
}
```

The view starts the stream once, when it first appears. If it disappears mid-stream the stream stops and is not restarted; give the view a new `.id` to start a new one.

## Own the model

A host that owns the lifetime creates a `StreamModel` and feeds it with `run(_:mode:onFinish:)`. That accepts an `AsyncThrowingStream<String, any Error>` or any sendable `AsyncSequence` of strings. `run(bytes:mode:onFinish:)` accepts UTF-8 chunks, and a scalar split across two chunks is safe. Calling `run` again after a stream ended starts from the initial spec and state.

`StreamModel` publishes small values: the snapshot, the phase (`idle`, `streaming`, `stopped`, `final`), the journal and the validation report. Live document text never goes into observable state.

## What the app sees

``SpecStore`` is an actor that applies patches and commits snapshots. A ``SpecSnapshot`` carries a version, the spec, the render plan, the `dangling` ids (listed by a parent but not defined yet; they draw as skeletons) and the journal. The journal holds ids, operations and paths, never values.

- One publish per display frame. A fast stream does not cost more frames.
- A budget breach (bytes, elements, depth, buffer) freezes the stream at the last good snapshot.
- Cancelling keeps the last snapshot, and the phase becomes `stopped`. A stream that throws ends the same way.
- When the stream ends, the final spec is validated. Ids that point at no element are pruned and the report reaches `onFinish`.
- While a stream runs, its `/state` wins over the live state model. After it finishes, the store belongs to the user.

## Writing order for a model

Send `/root` first, then elements (parents before children when you can), then `/state` patches one item at a time so a list fills row by row. A child that has not arrived is a skeleton, and an out-of-order child is kept until its parent arrives, so order is a quality choice and not a correctness one.
