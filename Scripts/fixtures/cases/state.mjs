// State and path helper cases. Source: packages/core/src/types.test.ts, state-store.test.ts.
// Each case: name, src ("<file>:<line>"), initial, ops, expected (final state).
// Op kinds: set, add, remove, get (with expect), patch (RFC 6902 line; optional throws),
// resolveRepeatStatePath, resolveRepeatItemStatePath, flatten, findFormValue.
// "$undefined": true marks an undefined value (README).
const U = { $undefined: true };
const T = "packages/core/src/types.test.ts";
const SS = "packages/core/src/state-store.test.ts";
const c = (name, src, initial, ops, expected = initial) => ({ name, src, initial, ops, expected });
const get = (path, expect) => ({ op: "get", path, expect });

export const state = [
  // getByPath
  c("get-nested-json-pointer", `${T}#gets nested values with JSON pointer`, { user: { name: "John", scores: [10, 20, 30] } }, [
    get("/user/name", "John"), get("/user/scores/0", 10), get("/user/scores/1", 20),
  ]),
  c("get-root-path", `${T}#returns root object for empty`, { value: 42 }, [get("/", { value: 42 }), get("", { value: 42 })]),
  c("get-missing-path", `${T}#returns undefined for missing paths`, { user: { name: "John" } }, [get("/user/missing", U), get("/nonexistent/path", U)]),
  c("get-path-without-leading-slash", `${T}#handles paths without leading slash|getByPath`, { user: { name: "John" } }, [get("user/name", "John")]),
  c("get-through-non-object", `${T}#returns undefined when traversing`, { value: "string" }, [get("/value/nested", U)]),
  c("get-through-null", `${T}#handles null values in path`, { user: null }, [get("/user/name", U)]),
  // RFC 6901 escaping
  c("get-unescape-tilde-1", `${T}#getByPath unescapes ~1`, { "a/b": { c: 42 } }, [get("/a~1b/c", 42)]),
  c("get-unescape-tilde-0", `${T}#getByPath unescapes ~0`, { "a~b": 99 }, [get("/a~0b", 99)]),
  c("get-combined-escapes", `${T}#getByPath handles combined`, { "a~/b": "found" }, [get("/a~0~1b", "found")]),
  c("set-unescape-tilde-1", `${T}#setByPath unescapes ~1`, {}, [{ op: "set", path: "/a~1b", value: "value" }], { "a/b": "value" }),
  c("set-unescape-tilde-0", `${T}#setByPath unescapes ~0`, {}, [{ op: "set", path: "/a~0b", value: "value" }], { "a~b": "value" }),
  c("get-array-elements", `${T}#getByPath reads array elements`, { items: [10, 20, 30] }, [get("/items/0", 10), get("/items/2", 30)]),
  // setByPath
  c("set-existing-path", `${T}#sets value at existing path`, { user: { name: "John" } }, [{ op: "set", path: "/user/name", value: "Alice" }], { user: { name: "Alice" } }),
  c("set-creates-intermediates", `${T}#creates intermediate objects for deep`, {}, [{ op: "set", path: "/a/b/c", value: "deep" }], { a: { b: { c: "deep" } } }),
  c("set-path-without-leading-slash", `${T}#handles paths without leading slash|setByPath`, {}, [{ op: "set", path: "user/name", value: "John" }], { user: { name: "John" } }),
  c("set-overwrites-existing", `${T}#overwrites existing values`, { count: 5 }, [{ op: "set", path: "/count", value: 10 }], { count: 10 }),
  c("set-array-like-path-on-object", `${T}#handles array-like paths`, { items: {} }, [{ op: "set", path: "/items/0", value: "first" }], { items: { "0": "first" } }),
  // addByPath
  c("add-object-property", `${T}#adds a property to an object`, { a: 1 }, [{ op: "add", path: "/b", value: 2 }], { a: 1, b: 2 }),
  c("add-replaces-object-property", `${T}#replaces an existing object property`, { a: 1 }, [{ op: "add", path: "/a", value: 99 }], { a: 99 }),
  c("add-inserts-into-array", `${T}#inserts into an array at a specific index`, { arr: [1, 2, 3] }, [{ op: "add", path: "/arr/1", value: 99 }], { arr: [1, 99, 2, 3] }),
  c("add-appends-with-dash", `${T}#appends to an array with -`, { arr: [1, 2] }, [{ op: "add", path: "/arr/-", value: 3 }], { arr: [1, 2, 3] }),
  c("add-inserts-at-index-zero", `${T}#inserts at index 0`, { arr: ["b", "c"] }, [{ op: "add", path: "/arr/0", value: "a" }], { arr: ["a", "b", "c"] }),
  c("add-creates-intermediates", `${T}#creates intermediate objects|addByPath`, {}, [{ op: "add", path: "/x/y/z", value: "deep" }], { x: { y: { z: "deep" } } }),
  // removeByPath
  c("remove-object-property", `${T}#deletes an object property`, { a: 1, b: 2 }, [{ op: "remove", path: "/a" }], { b: 2 }),
  c("remove-array-element", `${T}#removes an element from an array by index`, { arr: [1, 2, 3] }, [{ op: "remove", path: "/arr/1" }], { arr: [1, 3] }),
  c("remove-nested-property", `${T}#removes nested properties`, { user: { name: "John", age: 30 } }, [{ op: "remove", path: "/user/age" }], { user: { name: "John" } }),
  c("remove-nonexistent-is-noop", `${T}#is a no-op for non-existent paths`, { a: 1 }, [{ op: "remove", path: "/b/c/d" }], { a: 1 }),
  // untrusted paths
  c("proto-pollution-refused", `${T}#never writes to, reads from`, {}, [
    { op: "set", path: "/__proto__/polluted", value: true },
    { op: "add", path: "/__proto__/polluted", value: true },
    { op: "remove", path: "/__proto__/toString" },
    { op: "patch", patch: { op: "move", from: "/__proto__", path: "/alias" } },
    { op: "patch", patch: { op: "add", path: "/alias/polluted", value: true } },
  ], { alias: { polluted: true } }),
  c("no-holes-past-array-end", `${T}#ignores array indexes past the end`, { a: [0, {}, []] }, [
    { op: "set", path: "/a/9", value: 1 },
    { op: "add", path: "a/1000000000/x", value: 1 },
    { op: "add", path: "/a/-/1000000000/x", value: 1 },
    { op: "patch", patch: { op: "move", from: "/a/0", path: "/a/1/1000000000/x" } },
    { op: "add", path: "/a/2", value: "end" },
  ], { a: [{}, [], "end"] }),
  // resolveDynamicValue ($state only)
  c("dynamic-state-ref", `${T}#resolves $state references`, { user: { name: "Alice" } }, [get("/user/name", "Alice")]),
  // applySpecStreamPatch operations
  c("patch-add-property", `${T}#adds a new object property`, {}, [{ op: "patch", patch: { op: "add", path: "/name", value: "Alice" } }], { name: "Alice" }),
  c("patch-add-nested-creates-intermediates", `${T}#adds nested properties creating`, {}, [{ op: "patch", patch: { op: "add", path: "/user/name", value: "Bob" } }], { user: { name: "Bob" } }),
  c("patch-add-array-index", `${T}#inserts into array at index`, { items: [1, 3] }, [{ op: "patch", patch: { op: "add", path: "/items/1", value: 2 } }], { items: [1, 2, 3] }),
  c("patch-add-array-append", `${T}#appends to array with -`, { items: [1, 2] }, [{ op: "patch", patch: { op: "add", path: "/items/-", value: 3 } }], { items: [1, 2, 3] }),
  c("patch-remove-property", `${T}#removes an object property`, { name: "Alice", age: 30 }, [{ op: "patch", patch: { op: "remove", path: "/age" } }], { name: "Alice" }),
  c("patch-remove-array-index", `${T}#removes from array by index`, { items: ["a", "b", "c"] }, [{ op: "patch", patch: { op: "remove", path: "/items/1" } }], { items: ["a", "c"] }),
  c("patch-replace-value", `${T}#replaces an existing value`, { name: "Alice" }, [{ op: "patch", patch: { op: "replace", path: "/name", value: "Bob" } }], { name: "Bob" }),
  c("patch-replace-nested", `${T}#replaces nested values`, { user: { name: "Alice" } }, [{ op: "patch", patch: { op: "replace", path: "/user/name", value: "Bob" } }], { user: { name: "Bob" } }),
  c("patch-move-value", `${T}#moves a value from one path`, { a: 1, b: 2 }, [{ op: "patch", patch: { op: "move", path: "/c", from: "/a" } }], { b: 2, c: 1 }),
  c("patch-move-nested", `${T}#moves nested values`, { source: { val: 42 }, target: {} }, [{ op: "patch", patch: { op: "move", path: "/target/val", from: "/source/val" } }], { source: {}, target: { val: 42 } }),
  c("patch-move-without-from-is-noop", `${T}#is a no-op if from is missing|move`, { a: 1 }, [{ op: "patch", patch: { op: "move", path: "/b" } }], { a: 1 }),
  c("patch-copy-value", `${T}#copies a value from one path`, { a: 1 }, [{ op: "patch", patch: { op: "copy", path: "/b", from: "/a" } }], { a: 1, b: 1 }),
  c("patch-copy-complex-value", `${T}#copies complex values`, { source: { nested: { value: 42 } } }, [{ op: "patch", patch: { op: "copy", path: "/dest", from: "/source/nested" } }], { source: { nested: { value: 42 } }, dest: { value: 42 } }),
  c("patch-copy-without-from-is-noop", `${T}#is a no-op if from is missing|copy`, { a: 1 }, [{ op: "patch", patch: { op: "copy", path: "/b" } }], { a: 1 }),
  c("patch-test-matching-value", `${T}#succeeds when values match`, { name: "Alice" }, [{ op: "patch", patch: { op: "test", path: "/name", value: "Alice" } }]),
  c("patch-test-matching-object", `${T}#succeeds for matching objects`, { user: { name: "Alice", age: 30 } }, [{ op: "patch", patch: { op: "test", path: "/user", value: { name: "Alice", age: 30 } } }]),
  c("patch-test-matching-array", `${T}#succeeds for matching arrays`, { items: [1, 2, 3] }, [{ op: "patch", patch: { op: "test", path: "/items", value: [1, 2, 3] } }]),
  c("patch-test-mismatch-throws", `${T}#throws when values do not match`, { name: "Alice" }, [
    { op: "patch", patch: { op: "test", path: "/name", value: "Bob" }, throws: 'Test operation failed: value at "/name" does not match' },
  ]),
  c("patch-test-missing-path-throws", `${T}#throws when path does not exist`, {}, [
    { op: "patch", patch: { op: "test", path: "/missing", value: "anything" }, throws: true },
  ]),
  // resolveRepeatStatePath / resolveRepeatItemStatePath
  c("repeat-state-path-string-preserved", `${T}#preserves string paths exactly`, {}, [
    { op: "resolveRepeatStatePath", value: "/items", expect: "/items" },
    { op: "resolveRepeatStatePath", value: "items", expect: "items" },
  ]),
  c("repeat-state-path-item-relative", `${T}#resolves $item paths against the enclosing`, {}, [
    { op: "resolveRepeatStatePath", value: { $item: "subitems" }, base: "/groups/0", expect: "/groups/0/subitems" },
    { op: "resolveRepeatStatePath", value: { $item: "/subitems" }, base: "/groups/0", expect: "/groups/0/subitems" },
  ]),
  c("repeat-state-path-empty-item", `${T}#resolves an empty $item path`, {}, [
    { op: "resolveRepeatStatePath", value: { $item: "" }, base: "/groups/0", expect: "/groups/0" },
    { op: "resolveRepeatStatePath", value: { $item: "/" }, base: "/groups/0", expect: "/groups/0" },
  ]),
  c("repeat-state-path-item-outside-scope", `${T}#does not resolve $item outside`, {}, [
    { op: "resolveRepeatStatePath", value: { $item: "items" }, expect: U },
  ]),
  c("repeat-item-state-path", `${T}#builds item paths without duplicate`, {}, [
    { op: "resolveRepeatItemStatePath", base: "/items", index: 2, expect: "/items/2" },
    { op: "resolveRepeatItemStatePath", base: "/", index: 2, expect: "/2" },
    { op: "resolveRepeatItemStatePath", base: "items", index: 2, expect: "items/2" },
  ]),
  // flattenToPointers (state-store.test.ts)
  c("flatten-top-level-keys", `${SS}#flattens top-level keys`, { a: 1, b: "hello" }, [{ op: "flatten", expect: { "/a": 1, "/b": "hello" } }]),
  c("flatten-nested-objects", `${SS}#flattens nested plain objects`, { user: { name: "Alice", age: 30 } }, [{ op: "flatten", expect: { "/user/name": "Alice", "/user/age": 30 } }]),
  c("flatten-arrays-are-leaves", `${SS}#preserves arrays as leaf values`, { items: [1, 2, 3] }, [{ op: "flatten", expect: { "/items": [1, 2, 3] } }]),
  c("flatten-null-is-leaf", `${SS}#preserves null as a leaf value`, { x: null }, [{ op: "flatten", expect: { "/x": null } }]),
  c("flatten-deeply-nested", `${SS}#handles deeply nested objects|flattenToPointers`, { a: { b: { c: 42 } } }, [{ op: "flatten", expect: { "/a/b/c": 42 } }]),
  c("flatten-empty", `${SS}#returns empty object for empty input`, {}, [{ op: "flatten", expect: {} }]),
  c("flatten-mixed-nesting", `${SS}#handles mixed nesting`, { count: 1, user: { name: "Alice" }, tags: ["a", "b"] }, [
    { op: "flatten", expect: { "/count": 1, "/user/name": "Alice", "/tags": ["a", "b"] } },
  ]),
  // findFormValue
  c("form-value-direct-literal", `${T}#keeps a direct %s literal`, {}, [
    { op: "findFormValue", field: "email", params: { email: "john.doe@example.com" }, state: { email: "state" }, expect: "john.doe@example.com" },
  ]),
  c("form-value-dotted-key-literal", `${T}#keeps a dotted-key %s literal`, {}, [
    { op: "findFormValue", field: "email", params: { "form.email": "john.doe@example.com" }, state: { "form.email": "state" }, expect: "john.doe@example.com" },
  ]),
  c("form-value-raw-dotted-param-is-literal", `${T}#treats a raw dotted parameter`, {}, [
    { op: "findFormValue", field: "email", params: { email: "form.email" }, expect: "form.email" },
    { op: "findFormValue", field: "email", params: { email: "form.email" }, state: { "form.email": "state email" }, expect: "form.email" },
  ]),
  c("form-value-direct-beats-dotted-and-state", `${T}#prefers a direct parameter`, {}, [
    { op: "findFormValue", field: "email", params: { email: "direct", "form.email": "dotted" }, state: { email: "state", "form.email": "dotted state" }, expect: "direct" },
  ]),
  c("form-value-dotted-beats-state-skips-undefined-direct", `${T}#prefers a dotted parameter`, {}, [
    { op: "findFormValue", field: "email", params: { email: U, "form.email": "dotted" }, state: { "form.email": "state" }, expect: "dotted" },
  ]),
  c("form-value-first-dotted-key-wins-even-if-undefined", `${T}#keeps the first matching dotted`, {}, [
    { op: "findFormValue", field: "email", params: { "form.email": U, "other.email": "later" }, state: { email: "state" }, expect: U },
  ]),
  c("form-value-flat-state-keys", `${T}#finds exact and dotted flat state keys`, {}, [
    { op: "findFormValue", field: "email", state: { email: "exact" }, expect: "exact" },
    { op: "findFormValue", field: "email", state: { "form.email": "dotted state" }, expect: "dotted state" },
    { op: "findFormValue", field: "email", state: { email: "first", "form.email": "second" }, expect: "first" },
  ]),
  c("form-value-slash-paths-not-bare-names", `${T}#finds nested state with slash paths`, {}, [
    { op: "findFormValue", field: "/form/email", state: { form: { email: "nested@example.com" } }, expect: "nested@example.com" },
    { op: "findFormValue", field: "form/email", state: { form: { email: "nested@example.com" } }, expect: "nested@example.com" },
    { op: "findFormValue", field: "email", state: { form: { email: "nested@example.com" } }, expect: U },
  ]),
  c("form-value-nonmatching-and-omitted", `${T}#ignores nonmatching keys`, {}, [
    { op: "findFormValue", field: "email", params: { emailAddress: "other" }, state: {}, expect: U },
    { op: "findFormValue", field: "email", expect: U },
  ]),
  c("form-value-preserves-falsy-direct", `${T}#preserves a direct %s value`, {}, [
    { op: "findFormValue", field: "email", params: { email: "" }, state: { email: "state" }, expect: "" },
    { op: "findFormValue", field: "email", params: { email: 0 }, state: { email: "state" }, expect: 0 },
    { op: "findFormValue", field: "email", params: { email: false }, state: { email: "state" }, expect: false },
    { op: "findFormValue", field: "email", params: { email: null }, state: { email: "state" }, expect: null },
  ]),
];
