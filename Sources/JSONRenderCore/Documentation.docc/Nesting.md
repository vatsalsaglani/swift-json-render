# Nesting one spec in another

Put a whole spec inside an element of another spec, with no id or state clashes.

## Compose

``Spec/composing(_:into:slot:prefix:)`` inserts a child spec under a parent element and returns a new spec.

```swift
import JSONRenderCore

func embed(_ child: Spec, in parent: Spec) throws -> Spec {
    try parent.composing(child, into: "body", prefix: "detail")
}
```

The child can come from a different model, a different stream or a saved file. The parent keeps its own ids and state.

## The rewrite rules

- Every child id becomes `"<prefix>:<id>"`; `children` and `slots` follow.
- The child state moves under `/<prefix>` in the parent state. Every absolute state path inside the child moves with it: `$state`, `$bindState`, `${/…}` in `$template`, conditions and operands, `repeat.statePath`, `watch` keys, the `set` keys of `onSuccess` and `onError`, and the `statePath` and `clearStatePath` params of the state built-ins.
- `$item`, `$bindItem`, `$index` and relative repeat paths stay relative.
- The child root is appended to the parent's `children`, or to `slots[slot]` when you pass `slot`.
- Not rewritten: a bare `${name}` template name (it reads the repeat item first, so its meaning depends on the row) and the `${path}` text of `confirm`.

## When it refuses

The call throws ``ComposeError`` and changes nothing when the prefix is empty or holds `/`, `~` or `__proto__`; the parent element does not exist; a prefixed child id already exists; the parent state already has a member named by the prefix; or the parent state is not an object.

## Nested to flat

Upstream also has a nested form, where an element holds its children inline. ``Spec/nestedToFlat(_:)`` turns that into the flat spec this package renders, with the same output as upstream's `nestedToFlat`.
