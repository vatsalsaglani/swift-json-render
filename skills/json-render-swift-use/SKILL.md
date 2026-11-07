---
name: json-render-swift-use
description: Author, stream and edit json-render specs for swift-json-render, the native Swift and SwiftUI runtime of json-render, and wire the package into an app. Use when generating UI as JSON for a Swift or SwiftUI app, writing SpecStream JSONL patches, choosing among the 36 standard components and 15 charts, binding state and actions, theming, or installing or upgrading swift-json-render.
---

# swift-json-render: write and use specs

swift-json-render is a native Swift runtime for the json-render specification (https://github.com/vercel-labs/json-render). A model writes a small JSON tree, or streams it as JSONL patches, and SwiftUI draws it with native views. The catalog says which components and actions exist; the app owns the theme, the actions and every side effect. There is no web view and no code in a spec. Component names, prop names and action params are the upstream ones, so upstream specs and prompts carry over.

## The spec in 20 lines

```json
{
  "root": "card",
  "state": { "name": "Ada", "todos": [{ "id": "1", "title": "Ship", "done": false }] },
  "elements": {
    "card": { "type": "Card", "props": { "title": "Hello" }, "children": ["greet", "list"] },
    "greet": { "type": "Text", "props": { "text": { "$template": "Hi ${/name}" } }, "children": [] },
    "list": { "type": "Stack", "props": { "gap": "sm" }, "repeat": { "statePath": "/todos", "key": "id" }, "children": ["row"] },
    "row": { "type": "Checkbox", "props": { "label": { "$item": "title" }, "name": "done", "checked": { "$bindItem": "done" } }, "children": [] }
  }
}
```

- `elements` is a flat map; a parent lists child ids in `children` (always present, `[]` for a leaf).
- `props` carry content. `visible`, `on`, `repeat`, `watch` and `slots` sit on the element, never inside `props`.
- Dynamic values: `$state`, `$bindState`, `$item`, `$bindItem`, `$index`, `$cond`, `$computed`, `$template`, and custom directives such as `$format`.
- `state` seeds the data the expressions read.
- Details: [references/spec.md](references/spec.md).

## Which component

| Need | Use |
|---|---|
| Group content | `Card`; rows and columns with `Stack`; equal cells with `Grid` |
| Text | `Heading`, `Text`, `Badge`, `Alert`, `Link` |
| Rows of data | `Table`; actions per row with `repeat` over a `Stack` |
| Sections that share space | `Tabs` with `visible` panels, `Accordion`, `Collapsible` |
| Modal task | `Dialog` or `Drawer` with `openPath` |
| Input | `Input`, `Textarea`, `Select`, `Checkbox`, `Radio`, `Switch`, `Slider`, `Toggle`, `ToggleGroup`, `ButtonGroup`, `DropdownMenu` |
| Do something | `Button` (`on.press`) |
| One number | A `Card` with a `Heading`, not a chart |
| A series, parts, stages, a range | A chart: see [references/choosing.md](references/choosing.md) |

## Rules that keep specs valid

1. Use only components and actions the catalog lists. Do not invent names, props or events.
2. Every element has `type`, `props`, `children`. Every id in `children` or `slots` must exist.
3. `visible`, `on`, `repeat`, `watch` go on the element, never in `props`.
4. Put `$bindState` on the natural value prop of an input (`value`, `checked`, `pressed`, `selected`, `page`). Inside `repeat`, use `$bindItem`.
5. Include `state` for everything the UI reads (`$state`, `$bindState`, `$item`, `repeat`). Use realistic sample data. Show data with `$state`, not by repeating it in props.
6. Render lists with `repeat` and a `key` field. Never copy an element per item. At most 500 rows.
7. State paths are RFC 6901 pointers (`/todos/0/title`). No dot notation, no `.length`. Make ids with `"$id"` in `pushState`.
8. Use `setState`, `pushState`, `removeState` and `validateForm` for state changes; add `confirm` to destructive actions. Host actions (for example `saveProfile`) only if the prompt lists them.
9. Streaming order: `/root`, then elements, then `/state` patches right after the elements that read them, one patch per array item.
10. Keep it plain: three to five props, no colour or font props (the theme does that), one primary `Button` per view, status shown with a word and a sign, not colour alone.

## Check before you answer

- Walk the tree from `root`; every id resolves.
- Every input has `label`, `name`, a bound value and `checks`.
- Every `$bindItem`, `$item` and `$index` is inside a `repeat`.
- Charts follow [references/charts.md](references/charts.md) limits (pie at most 6 slices, no dual axis).
- Validate in code with `Catalog.validate` ([references/spec.md](references/spec.md#validate)); treat `unknown_component` and `invalid_props` as rejects.

## Not supported in 0.22.x

- YAML specs; the spec is JSON.
- Merge and diff edit modes; patch mode only.
- The `$math`, `$concat`, `$truncate` and `$t` directives; `$format`, `$count`, `$join`, `$pluralize` are shipped.
- Loading remote images from the core package; use the optional `JSONRenderRemoteImages` product with consent.
- MCP: the app's own tools replace upstream's MCP package. The Rafu app documents its tools in its own `rafu-view` skill.
- Components outside the 36 and the 15 charts. An app may add its own with `@JRComponent`.

## References

- [references/spec.md](references/spec.md): read when you write or review the JSON: element fields, the expressions, visibility, repeat, slots, watch, limits, validation.
- [references/actions.md](references/actions.md): read when a spec has buttons or forms: built-in actions, the Swift-only `toggleState` and `incrementState`, `confirm`, `onSuccess`, `onError`, host actions, what the host gates.
- [references/streaming.md](references/streaming.md): read when output is streamed or edited: patch lines, order, the chat `spec` fence, object mode, edits, budgets, the view.
- [references/components.md](references/components.md): read when you pick or fill a standard component: props, extras, slots, events, notes.
- [references/charts.md](references/charts.md): read when data is a series, parts or a range: the 15 charts, shared props, rules, budgets.
- [references/choosing.md](references/choosing.md): read when unsure which element fits the data, or to avoid anti-patterns.
- [references/customising.md](references/customising.md): read when the app changes the look or adds components, actions, functions or directives.
- [references/install.md](references/install.md): read when adding the package, rendering or streaming a spec, or giving a model the prompt.
- [references/upgrade.md](references/upgrade.md): read when changing the package version or re-validating stored specs.
- [references/security.md](references/security.md): read when a spec comes from a model or a user, or touches images, links or secrets.

## Examples

- `examples/card-table.json`: Card, Tabs, Table, and a repeated row with a confirmed `removeState`.
- `examples/form.json`: Inputs with checks, `validateForm`, a host action with `onSuccess` and `onError`.
- `examples/dashboard.json`: stat cards, a stacked BarChart with selection, a Gauge with bands.
- `examples/stream.jsonl`: a streamed list with `/state` patches.
- `examples/chat-fence.txt`: prose plus a `spec` fence.
