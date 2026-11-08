# Expressions

Any prop can be a small expression that reads state. Specs carry no code.

## The built-in expressions

| Expression | Reads |
|---|---|
| `{ "$state": "/path" }` | The state at a JSON Pointer. One-way |
| `{ "$bindState": "/path" }` | The same, and the component writes back. Put it on the natural value prop |
| `{ "$cond": C, "$then": A, "$else": B }` | A or B. `C` uses the visibility syntax |
| `{ "$template": "Hi ${/user/name}" }` | A string with state values filled in |
| `{ "$item": "field" }` | A field of the current repeat item |
| `{ "$index": true }` | The index of the current repeat item |
| `{ "$bindItem": "field" }` | A field of the repeat item, with write-back |
| `{ "$computed": "name", "args": {} }` | A function the host registered |

A missing path is undefined, not an error. State paths are RFC 6901 JSON Pointers; `__proto__` is refused everywhere.

## Computed values come from the host

`$computed` calls a function by name. The host registers the function in Swift; a spec cannot define one, and an unknown name gives undefined.

```swift
import JSONRenderCore

func catalogWithFullName() -> Catalog {
    var catalog = Catalog()
    catalog.function("fullName", description: "Join a first and a last name") { args in
        let first = (args["first"] ?? nil)?.stringValue ?? ""
        let last = (args["last"] ?? nil)?.stringValue ?? ""
        return .string("\(first) \(last)")
    }
    return catalog
}
```

The charts product registers four aggregations the same way: `groupSum`, `countBy`, `topN` and `bucket`.

## Directives

A directive is a custom `$name` expression that a catalog registers. The standard catalog ships four, with upstream's output:

```json
{ "$format": "currency", "value": { "$state": "/cart/total" }, "currency": "USD" }
{ "$count": { "$state": "/cart/items" } }
{ "$join": { "$state": "/tags" }, "separator": ", " }
{ "$pluralize": { "$state": "/cart/itemCount" }, "one": "item", "other": "items", "zero": "no items" }
```

`$format` takes `date`, `currency`, `number` or `percent`. A directive name starts with `$` and cannot reuse a built-in key; register one with ``Catalog/directive(_:)``.

## Visibility and repeat

`visible` takes the same kind of reads: `{ "$state": "/tab", "eq": "home" }`, with `eq`, `neq`, `gt`, `gte`, `lt`, `lte` and `not`, plus `$and`, `$or`, or an array that means all. A shape the runtime cannot evaluate is hidden and reported. Inside a `repeat`, `$item` and `$index` also work in conditions and filter rows.

## Actions

`on` binds an event to a named action. Built-in actions change state (`setState`, `pushState`, `removeState`, plus `validateForm`, and the Swift extras `toggleState` and `incrementState`). Any other name runs only if the host registered it with ``Catalog/action(_:params:description:handler:)``; confirmations, navigation and links go through the `ActionHost`.
