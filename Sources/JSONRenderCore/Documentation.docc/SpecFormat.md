# The spec format

One flat JSON document describes the whole interface.

## Shape

A spec has a `root` id, an `elements` map from id to element, and an optional `state` object that seeds the state model. A parent lists the ids of its children; it never nests them.

```json
{
  "root": "card",
  "state": { "name": "Ada" },
  "elements": {
    "card": { "type": "Card", "props": { "title": "Hello" }, "children": ["greet"] },
    "greet": { "type": "Text", "props": { "text": { "$template": "Hi ${/name}" } }, "children": [] }
  }
}
```

## Element fields

| Field | Meaning |
|---|---|
| `type` | A component name from the catalog |
| `props` | The component's props. A value can be an expression (see <doc:Expressions>) |
| `children` | Child ids. Always write it; a leaf has `[]` |
| `slots` | Named child regions, such as `{ "footer": ["actions"] }` |
| `visible` | A condition that shows or hides the element |
| `on` | Event name to one action binding or an array of bindings |
| `repeat` | Draw the children once per item of a state array |
| `watch` | State path to action bindings, run when the value changes |

`visible`, `on`, `repeat` and `watch` belong on the element, never inside `props`. The validator reports a misplaced one, and ``Catalog/autoFix(_:lossy:)`` moves it.

## Decode and validate

``Spec/decode(_:limits:)`` checks the byte size and the nesting depth, parses the JSON and returns a ``DecodedSpec`` with the spec and any warnings, such as an unknown element key that it dropped.

```swift
import Foundation
import JSONRenderCore
import JSONRenderStandardCatalog

func check(_ data: Data) throws {
    let decoded = try Spec.decode(data)
    for warning in decoded.warnings { print("warning:", warning) }
    let catalog = try Catalog.standard
    let report = catalog.validate(decoded.spec)
    if !report.valid { print(report.formatted()) }
}
```

Validation reports ids, paths and type names. It never repeats a prop value or a state value.

## Limits

``SpecLimits`` caps one spec. A host can lower a cap, never raise it.

| Limit | Value | Over the limit |
|---|---|---|
| Spec size | 256 KiB | A decode error |
| Elements | 2,000 | The validator reports it |
| Nesting depth | 64 | The subtree draws as a calm fallback block |
| Repeat rows | 500 | The rows after 500 are not drawn |

A stream buffer holds at most 64 KiB for one partial line.

## nil and null

Swift keeps two empty values apart. `nil` means no value: a missing path, an absent prop. ``JSONValue/null`` means the spec wrote JSON `null`. A spec cannot write the first.
