# Actions

Contents: binding shape, built-in actions, Swift-only extensions, confirm, onSuccess and onError, host actions, what the host gates.

## Binding shape

Events bind to actions in the element field `on`. The key is an event name the component declares (`press`, `change`, `submit`, `select`, ...).

```json
"on": {
  "press": {
    "action": "setState",
    "params": { "statePath": "/saved", "value": true }
  }
}
```

| Field | Meaning |
|---|---|
| `action` | A built-in or a host-registered action name |
| `params` | Object; values may be expressions (`$state`, `$item`, `$index`, `$template`, ...) |
| `confirm` | A dialog the user must accept first |
| `onSuccess` | What runs after the handler succeeds |
| `onError` | What runs when the handler throws |
| `preventDefault` | Ask the host to skip its default behaviour for the event |

`on.press` may be one binding or an array. An array runs in order; if the user declines a `confirm`, the later bindings do not run.

Never put `action` or `actionParams` inside `props`. Never invent an event name: use the ones in the component's `[events: ...]` list.

## Built-in actions

These need no host code. The prompt lists them with `[built-in]`.

| Action | Params | Effect |
|---|---|---|
| `setState` | `statePath`, `value` | Writes `value` at `statePath`. An undefined value removes the path |
| `pushState` | `statePath`, `value`, `clearStatePath?` | Appends `value` to the array. Then sets `clearStatePath` to `""` |
| `removeState` | `statePath`, `index` | Removes the array item at `index` |
| `validateForm` | `statePath?` | Validates every registered field. Writes `{ "valid": bool, "errors": { "<field path>": ["message"] } }` to `statePath` (default `/formValidation`) |

`pushState` values may hold `{ "$state": "/path" }` (read current state) and `"$id"` (a new unique id). Add a todo and clear the field:

```json
"on": { "press": { "action": "pushState", "params": {
  "statePath": "/todos",
  "value": { "id": "$id", "title": { "$state": "/newTodo" }, "completed": false },
  "clearStatePath": "/newTodo"
} } }
```

Remove the current row: `{ "action": "removeState", "params": { "statePath": "/todos", "index": { "$index": true } } }`.

Set a field of the current row: `{ "action": "setState", "params": { "statePath": { "$item": "done" }, "value": true } }`. In a param, `$item` is the absolute state path of that field.

Use `pushState` and `removeState` for lists the user edits. Use `$bindItem` for a field the user changes directly.

Built-ins do not run `onSuccess` or `onError`. For a form, run `validateForm`, then show the submit button when `/formValidation/valid` is true (see `examples/form.json`).

## Swift-only extensions

`toggleState` and `incrementState` are Swift additions, not upstream json-render. The prompt lists them after the four built-ins when `PromptOptions.includeExtensions` is `true` (the default). Another json-render renderer ignores them, so do not use them in a spec that must also run on the web.

| Action | Params | Effect |
|---|---|---|
| `toggleState` | `statePath` | Flips a boolean. A missing or `null` value becomes `true` |
| `incrementState` | `statePath`, `by?` | Adds `by` (default 1). A missing or non-number value counts as 0 |

```json
"on": { "press": { "action": "toggleState", "params": { "statePath": "/menuOpen" } } }
```

## Confirm

```json
"confirm": {
  "title": "Delete this run?",
  "message": "The run leaves this list.",
  "confirmLabel": "Delete",
  "cancelLabel": "Keep",
  "variant": "danger"
}
```

`confirmLabel`, `cancelLabel` and `variant` (`default` or `danger`) are optional. `${/path}` in `title` and `message` reads state only. Every action honours `confirm`, built-ins too (upstream ignores it on built-ins). The host shows the dialog (`ActionHost.confirm`). Put `confirm` on destructive actions.

## onSuccess and onError

```json
"on": { "press": {
  "action": "saveProfile",
  "params": { "name": { "$state": "/form/name" } },
  "onSuccess": { "set": { "/saved": true } },
  "onError": { "set": { "/saveError": "$error.message" } }
} }
```

| Field | Forms |
|---|---|
| `onSuccess` | `{ "navigate": "/path" }`, `{ "set": { "/path": value } }`, `{ "action": "name", "params": { ... } }` |
| `onError` | `{ "set": { "/path": value } }` (the literal string `"$error.message"` becomes the error message), `{ "action": "name", "params": { ... } }` |

`set` writes all its paths in one commit. If a handler throws and there is no `onError`, the error goes back to the caller. The host sees `navigate`; the spec cannot open a URL by itself.

## Host actions

A spec can only name actions the app registered. An unknown name does nothing (outcome `noHandler`), so use only actions the prompt lists.

```swift
import JSONRenderCore
import JSONRenderStandardCatalog

func makeCatalog() throws -> Catalog {
    var catalog = try Catalog.standard
    catalog.action(
        "saveProfile",
        params: .object([
            .init(name: "name", schema: .string),
            .init(name: "email", schema: .string),
        ]),
        description: "Save the profile. Params: { name, email }"
    ) { params, _ in
        guard let name = params["name"] ?? nil, name.stringValue?.isEmpty == false else {
            throw ActionFailure("Name is empty")
        }
        return .object(["saved": true])
    }
    return catalog
}
```

The handler receives resolved params (`nil` means undefined) and the `ActionHost`. A thrown `ActionFailure` message reaches `$error.message`. Write the description so a model knows when to use the action.

## What the host gates

Every user-visible effect goes through the `ActionHost` the app passes to the renderer:

```swift
import Foundation
import JSONRenderCore

struct AppHost: ActionHost {
    func confirm(_ confirm: ActionConfirm, action: String) async -> Bool { true }
    func navigate(_ path: String) async {}
    func openURL(_ url: URL) async -> Bool { false }
}
```

- `confirm` shows the dialog and answers `true` or `false`.
- `navigate` handles `onSuccess.navigate`.
- `openURL` opens a `Link` href. It runs only when the element has no `on.press` <!-- verify after jr-3 merges -->.
- `NoopActionHost` confirms everything and opens nothing; use it in tests.
- A spec cannot run code, make a network call, read a file or open a window. Only registered handlers do.

An `ActionObserver` (optional) sees action ids, names, element ids and outcomes (`completed`, `cancelled`, `noHandler`, `unavailable`, `failed`), never params or results.
