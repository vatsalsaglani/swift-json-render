// Spec validator and auto-fix cases. Source: packages/core/src/spec-validator.test.ts.
// has: issue codes the upstream test asserts are present. exact: the test asserts the whole
// issue list (then codes is complete); otherwise the case is recorded partial.
// counts: { code: n } where the test asserts an exact count of one code.
const F = "packages/core/src/spec-validator.test.ts";
const el = (type, props = {}, children = [], extra = {}) => ({ type, props, children, ...extra });
const v = (name, frag, spec, has, rest = {}) => ({ name, src: `${F}#${frag}`, kind: "validate", spec, has, ...rest });
const fix = (name, frag, spec, rest = {}) => ({ name, src: `${F}#${frag}`, kind: "autofix", spec, ...rest });

export const validator = [
  v("valid-spec", "returns valid for a correct spec", {
    root: "root", elements: { root: el("Stack", {}, ["child1"]), child1: el("Text", { text: "hello" }) } }, [], { exact: true }),
  v("missing-root", "detects missing root", { root: "", elements: { a: el("T") } }, ["missing_root"]),
  v("root-not-found", "detects root_not_found", { root: "missing", elements: { a: el("T") } }, ["root_not_found"]),
  v("empty-spec", "detects empty spec", { root: "r", elements: {} }, ["empty_spec"]),
  v("missing-child", "detects missing_child", { root: "root", elements: { root: el("Stack", {}, ["nonexistent"]) } }, ["missing_child"]),
  v("missing-child-in-named-slot", "detects missing children in named slots", {
    root: "root", elements: { root: { type: "Layout", props: {}, slots: { header: ["nonexistent"] } } } },
    ["missing_child"], { slotMessageContains: 'slot "header"', elementKey: "root" }),
  v("visible-in-props", "detects visible_in_props", {
    root: "root", elements: { root: el("Text", { visible: { $state: "/show" } }) } }, ["visible_in_props"]),
  v("on-in-props", "detects on_in_props", {
    root: "root", elements: { root: el("Button", { on: { press: { action: "doSomething" } } }) } }, ["on_in_props"]),
  v("repeat-in-props", "detects repeat_in_props", {
    root: "root", elements: { root: el("Stack", { repeat: { statePath: "/items" } }) } }, ["repeat_in_props"]),
  v("watch-in-props", "detects watch_in_props", {
    root: "root", elements: { root: el("Select", { watch: { "/form/country": { action: "loadCities" } } }) } },
    ["watch_in_props"], { elementKey: "root" }),
  v("orphaned-element-with-check-orphans", "detects orphaned elements when checkOrphans", {
    root: "root", elements: { root: el("Stack"), orphan: el("Text") } }, ["orphaned_element"], { options: { checkOrphans: true } }),
  v("named-slot-children-are-reachable", "treats named slot children as reachable", {
    root: "root", elements: { root: { type: "Layout", props: {}, slots: { header: ["heading"] } }, heading: { type: "Heading", props: {} } } },
    [], { options: { checkOrphans: true }, exact: true }),
  v("repeat-without-children", "rejects repeat without children", {
    root: "list", state: { items: [{ id: "1" }] },
    elements: { list: el("Stack", {}, [], { repeat: { statePath: "/items" } }) } }, ["repeat_without_children"]),
  v("repeat-over-non-array-state", "rejects repeat over a non-array state value", {
    root: "list", state: { items: { 1: { title: "x" } } },
    elements: { list: el("Stack", {}, ["card"], { repeat: { statePath: "/items" } }), card: el("Text") } }, ["repeat_state_mismatch"]),
  v("repeat-over-missing-state-path", "rejects repeat over a missing state path", {
    root: "list", state: { other: [] },
    elements: { list: el("Stack", {}, ["card"], { repeat: { statePath: "/items" } }), card: el("Text") } }, ["repeat_state_mismatch"]),
  v("repeat-well-formed-with-state", "accepts a well-formed repeat", {
    root: "list", state: { items: [{ id: "1" }] },
    elements: { list: el("Stack", {}, ["card"], { repeat: { statePath: "/items" } }), card: el("Text") } }, [], { exact: true }),
  v("repeat-well-formed-without-state", "accepts a well-formed repeat", {
    root: "list",
    elements: { list: el("Stack", {}, ["card"], { repeat: { statePath: "/items" } }), card: el("Text") } }, [], { exact: true }),
  v("repeat-nested-relative-to-item", "accepts a nested repeat relative", {
    root: "groups", state: { groups: [{ subitems: [{ label: "a" }] }] },
    elements: {
      groups: el("Stack", {}, ["subitems"], { repeat: { statePath: "/groups" } }),
      subitems: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "subitems" } } }),
      label: el("Text") } }, [], { exact: true }),
  v("repeat-item-outside-scope", "rejects a relative repeat outside repeat scope", {
    root: "items", state: { items: [{ label: "root" }] },
    elements: { items: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "items" } } }), label: el("Text") } },
    ["repeat_item_outside_scope"]),
  v("repeat-slots-do-not-get-element-repeat-scope", "does not give named slots the repeat scope", {
    root: "items", state: { items: [{ nested: [] }] },
    elements: {
      items: { type: "Layout", props: {}, repeat: { statePath: "/items" }, children: ["body"], slots: { header: ["nested"] } },
      body: el("Text"),
      nested: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "nested" } } }),
      label: el("Text") } }, ["repeat_item_outside_scope"]),
  v("repeat-nested-with-empty-outer-array", "accepts relative repeat structure when the outer sample array is empty", {
    root: "groups", state: { groups: [] },
    elements: {
      groups: el("Stack", {}, ["subitems"], { repeat: { statePath: "/groups" } }),
      subitems: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "subitems" } } }),
      label: el("Text") } }, [], { exact: true, validOnly: true }),
  v("repeat-nested-relative-not-array", "rejects a nested relative repeat that does not resolve", {
    root: "groups", state: { groups: [{ subitems: { label: "a" } }] },
    elements: {
      groups: el("Stack", {}, ["subitems"], { repeat: { statePath: "/groups" } }),
      subitems: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "/subitems" } } }),
      label: el("Text") } }, ["repeat_state_mismatch"]),
  v("repeat-issue-not-duplicated-per-structural-context", "does not duplicate repeat issues", {
    root: "root", state: { items: [] },
    elements: {
      root: el("Stack", {}, ["left", "right"]), left: el("Stack", {}, ["shared"]), right: el("Stack", {}, ["shared"]),
      shared: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "items" } } }), label: el("Text") } },
    ["repeat_item_outside_scope"], { counts: { repeat_item_outside_scope: 1 } }),
  v("repeat-reused-inside-and-outside-scope", "validates a reused repeat separately", {
    root: "root", state: { groups: [{ items: [] }] },
    elements: {
      root: el("Stack", {}, ["groups", "shared"]),
      groups: el("Stack", {}, ["shared"], { repeat: { statePath: "/groups" } }),
      shared: el("Stack", {}, ["label"], { repeat: { statePath: { $item: "items" } } }), label: el("Text") } },
    ["repeat_item_outside_scope"], { counts: { repeat_item_outside_scope: 1, repeat_state_mismatch: 0 } }),
  v("repeat-terminates-on-cyclic-children", "terminates repeat validation for cyclic child graphs", {
    root: "groups", state: { groups: [{ items: [] }] },
    elements: {
      groups: el("Stack", {}, ["items"], { repeat: { statePath: "/groups" } }),
      items: el("Stack", {}, ["groups"], { repeat: { statePath: { $item: "items" } } }) } },
    [], { counts: { repeat_state_mismatch: 0 } }),
  ...[
    ["visible-true", true], ["visible-false", false],
    ["visible-state-eq", { $state: "/tab", eq: "home" }], ["visible-item-eq", { $item: "status", eq: "todo" }],
    ["visible-index-lt", { $index: true, lt: 3 }],
    ["visible-implicit-and-array", [{ $state: "/a", eq: 1 }, { $item: "b", neq: 2 }]],
    ["visible-or-with-nested-and", { $or: [{ $state: "/a", eq: 1 }, { $and: [{ $item: "b", not: true }] }] }],
  ].map(([name, visible]) =>
    v(name, "accepts documented forms", { root: "root", elements: { root: el("Text", { text: "hi" }, [], { visible }) } }, [], { exact: true })),
  v("visible-mixing-state-and-item-rejected", "rejects conditions mixing", {
    root: "root", elements: { root: el("Text", { text: "hi" }, [], { visible: [{ $state: "/tasks", $item: "status", eq: "todo" }] }) } },
    ["invalid_visible"]),
  v("visible-unknown-shape-rejected", "rejects unknown condition shapes", {
    root: "root", elements: { root: el("Text", { text: "hi" }, [], { visible: { when: "/tasks", is: "todo" } }) } },
    ["invalid_visible"], { firstCode: "invalid_visible" }),

  fix("autofix-prunes-undefined-children", "prunes children references to undefined elements", {
    root: "root", elements: { root: el("Card", {}, ["text", "ghost"]), text: el("Text", { text: "hi" }) } }),
  fix("autofix-leaves-intact-children", "leaves intact children untouched", {
    root: "root", elements: { root: el("Card", {}, ["text"]), text: el("Text", { text: "hi" }) } }),
  fix("autofix-prunes-undefined-slot-children", "prunes undefined children from named slots", {
    root: "root", elements: { root: { type: "Layout", props: {}, slots: { header: ["heading", "ghost"] } }, heading: { type: "Heading", props: {} } } }),
  fix("autofix-keeps-repeat-container-children", "does not prune a repeat container down to zero", {
    root: "list", state: { items: [{ id: "1" }] },
    elements: { list: el("Stack", {}, ["ghost"], { repeat: { statePath: "/items" } }) } }),
  fix("autofix-withholds-lossy-fixes", "withholds lossy fixes", {
    root: "root", elements: { root: el("Card", { visible: true }, ["ghost"]) } }, { options: { lossy: false } }),
  fix("autofix-field-relocation-is-lossless", "classifies field relocations as lossless", {
    root: "root", elements: { root: el("Text", { text: "hi", visible: true }) } }),
  fix("autofix-moves-visible-to-element", "moves visible from props to element level", {
    root: "root", elements: { root: el("Text", { text: "hi", visible: { $state: "/show" } }) } }),
  fix("autofix-moves-on-to-element", "moves on from props to element level", {
    root: "root", elements: { root: el("Button", { label: "OK", on: { press: { action: "submit" } } }) } }),
  fix("autofix-moves-repeat-to-element", "moves repeat from props to element level", {
    root: "root", elements: { root: el("Stack", { repeat: { statePath: "/items" } }, ["child"]), child: el("Text") } }),
  fix("autofix-moves-watch-to-element", "moves watch from props to element level", {
    root: "root", elements: { root: el("Select", { label: "Country", watch: { "/form/country": { action: "loadCities" } } }) } }),
  fix("autofix-no-fixes-for-correct-spec", "returns no fixes for a correct spec", {
    root: "root", elements: { root: el("Stack", { direction: "vertical" }, [], { watch: { "/x": { action: "y" } } }) } }),
];
