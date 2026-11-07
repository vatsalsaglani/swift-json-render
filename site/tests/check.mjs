// Quality gate for the showcase site. Run: node site/tests/check.mjs
//  1. registry shape and counts (36 standard, 15 charts, 15 Rafu), components.js in sync with components.json
//  2. every example and every variant renders with the real renderer, no throw, non-empty, no error placeholder
//  3. every handler in every example runs and re-renders without a throw
//  4. interpreter behaviour: $state, $bindState, $cond, $template, visible, repeat, setState, toggleState, incrementState
//  5. streaming transcripts replay, y-domain only grows, final spec has no dangling ids
//  6. Treemap layout tiles its rectangle exactly
//  7. internal links, script and style references, hygiene patterns, total size
import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const SITE = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const at = (...p) => path.join(SITE, ...p);

['js/vnode.js', 'js/engine.js', 'js/render.js', 'js/charts.js', 'js/ui.js', 'js/stream-data.js', 'data/components.js'].forEach((f) => require(at(f)));
const JR = globalThis.JR;
const E = JR.engine;

let passed = 0;
const failures = [];
function check(name, fn) {
  try { fn(); passed++; } catch (e) { failures.push(name + ': ' + (e && e.message ? e.message.split('\n')[0] : e)); }
}

/* ---------- 1. registry ---------- */
const json = JSON.parse(fs.readFileSync(at('data/components.json'), 'utf8'));
const comps = json.components;
const STANDARD = ['Card', 'Stack', 'Grid', 'Separator', 'Tabs', 'Accordion', 'Collapsible', 'Pagination', 'Dialog', 'Drawer', 'Tooltip', 'Popover', 'DropdownMenu', 'Heading', 'Text', 'Image', 'Avatar', 'Badge', 'Alert', 'Carousel', 'Table', 'Progress', 'Skeleton', 'Spinner', 'Button', 'Link', 'Input', 'Textarea', 'Select', 'Checkbox', 'Radio', 'Switch', 'Slider', 'Toggle', 'ToggleGroup', 'ButtonGroup'];
const CHARTS = ['BarChart', 'LineChart', 'AreaChart', 'PieChart', 'Gauge', 'Sparkline', 'ScatterChart', 'Heatmap', 'Histogram', 'ComboChart', 'Waterfall', 'Funnel', 'BoxPlot', 'Candlestick', 'Treemap'];
const RAFU = ['Stat', 'Chart', 'KeyValue', 'Timeline', 'Markdown', 'Mermaid', 'Code', 'Callout', 'Checklist', 'FileLink', 'CardLink', 'TerminalStatus', 'AgentStatus', 'DiffSummary', 'IconLibraryIcon'];
const GROUPS = ['layout', 'content', 'form', 'overlay', 'navigation', 'data', 'chart', 'rafu-extension'];

check('registry: 36 standard components by name', () => assert.deepEqual(comps.filter((c) => c.catalog === 'standard').map((c) => c.name).sort(), [...STANDARD].sort()));
check('registry: 15 charts by name', () => assert.deepEqual(comps.filter((c) => c.catalog === 'charts').map((c) => c.name).sort(), [...CHARTS].sort()));
check('registry: 15 Rafu additions by name', () => assert.deepEqual(comps.filter((c) => c.catalog === 'rafu').map((c) => c.name).sort(), [...RAFU].sort()));
check('registry: names are unique', () => assert.equal(new Set(comps.map((c) => c.name)).size, comps.length));
comps.forEach((c) => {
  check(`registry: ${c.name} shape`, () => {
    assert.ok(GROUPS.includes(c.group), 'group ' + c.group);
    assert.ok(c.description && c.swiftui, 'description and swiftui mapping');
    assert.ok(Array.isArray(c.props) && Array.isArray(c.events) && Array.isArray(c.slots) && Array.isArray(c.variants), 'arrays');
    assert.ok(c.examples.length >= 1 && c.examples.length <= 3, '1 to 3 examples');
    c.props.forEach((p) => { assert.ok(p.name && p.type, 'prop name and type'); assert.equal(typeof p.required, 'boolean'); assert.ok('default' in p && 'note' in p); });
    c.examples.forEach((ex) => {
      assert.ok(ex.spec.root && ex.spec.elements[ex.spec.root], 'root element exists');
      Object.values(ex.spec.elements).forEach((el) => { assert.ok(el.type && el.props, 'type and props'); (el.children || []).forEach((id) => assert.ok(ex.spec.elements[id], 'child ' + id + ' exists')); Object.values(el.slots || {}).forEach((l) => l.forEach((id) => assert.ok(ex.spec.elements[id], 'slot child ' + id))); });
    });
  });
});
check('registry: components.js is in sync with components.json', () => assert.deepEqual(JR.registry, json));

/* ---------- 2 and 3. render every example and variant; run every handler ---------- */
function walk(v, f) { if (typeof v === 'string') return; f(v); v.c.forEach((x) => walk(x, f)); }
const fakeEvent = (extra) => ({ target: { value: '5', checked: true }, currentTarget: { children: [] }, key: 'Enter', preventDefault() {}, ...extra });
let rendered = 0, variantsRendered = 0, handlersRun = 0;
const renderedNames = new Set();

function renderOnce(spec, opts = {}) {
  const store = E.createStore(spec.state);
  const v = JR.render(spec, store, { strict: true, ...opts });
  const html = JR.toHTML(v);
  assert.ok(html.length > 30, 'empty output');
  assert.ok(!/jr-note/.test(html), 'error placeholder in output: ' + (html.match(/jr-note[^<]*<[^>]*>[^<]*/) || [''])[0].slice(0, 120));
  return { store, v, html };
}

comps.forEach((c) => {
  c.examples.forEach((ex, i) => {
    check(`render: ${c.name} example ${i + 1}`, () => {
      const { v, store } = renderOnce(ex.spec);
      const dense = renderOnce(ex.spec, { dense: true });
      assert.ok(dense.html.length > 30);
      rendered++; renderedNames.add(c.name);
      /* run every handler (click, change, input), re-rendering after each */
      const handlers = [];
      walk(v, (n) => { const on = n.a && n.a.on; if (on) Object.keys(on).forEach((k) => { if (k === 'click' || k === 'change' || k === 'input') handlers.push(on[k]); }); });
      handlers.forEach((fn) => { fn(fakeEvent()); handlersRun++; JR.toHTML(JR.render(ex.spec, store, { strict: true })); });
    });
  });
  c.variants.forEach((vr, i) => {
    check(`render: ${c.name} variant "${vr.label}"`, () => { renderOnce(JR.ui.variantSpec(c, vr)); variantsRendered++; });
  });
  check(`swift definition: ${c.name}`, () => assert.ok(JR.ui.swiftDef(c).startsWith(c.name + ': .component(')));
});
check('render: all 66 registry components rendered at least once', () => { assert.equal(renderedNames.size, comps.length); assert.equal(comps.length, 66); });

/* ---------- 4. interpreter behaviour ---------- */
function find(v, pred) { let out = null; walk(v, (n) => { if (!out && pred(n)) out = n; }); return out; }
function drawText(spec, store) { return JR.vtext(JR.render(spec, store, { strict: true })); }

check('$bindState: Input writes state and Text reads it (live update)', () => {
  const ex = JR.ui.byName('Input').examples[0].spec, store = E.createStore(ex.state);
  const v = JR.render(ex, store, { strict: true });
  const input = find(v, (n) => n.t === 'input');
  assert.ok(JR.vtext(v).includes('Type a name above.'));
  input.a.on.input({ target: { value: 'Ada' } });
  assert.equal(store.get('/form/name'), 'Ada');
  assert.ok(drawText(ex, store).includes('Hello, Ada'));
});
check('$cond + $bindState: Checkbox gates a disabled Button', () => {
  const ex = JR.ui.byName('Checkbox').examples[0].spec, store = E.createStore(ex.state);
  const html0 = JR.toHTML(JR.render(ex, store, {}));
  assert.ok(/<button[^>]*disabled/.test(html0), 'starts disabled');
  find(JR.render(ex, store, {}), (n) => n.t === 'input').a.on.change({ target: { checked: true } });
  assert.ok(!/<button[^>]*disabled/.test(JR.toHTML(JR.render(ex, store, {}))), 'enabled after tick');
});
check('visible: Alert shows only when /failures > 0; incrementState', () => {
  const ex = JR.ui.byName('Alert').examples[0].spec, store = E.createStore(ex.state);
  assert.ok(!drawText(ex, store).includes('failing'));
  find(JR.render(ex, store, {}), (n) => n.t === 'button').a.on.click();
  assert.equal(store.get('/failures'), 1);
  assert.ok(drawText(ex, store).includes('1 failing'));
});
check('visible + $bindState: Tabs switch panels', () => {
  const ex = JR.ui.byName('Tabs').examples[0].spec, store = E.createStore(ex.state);
  assert.ok(drawText(ex, store).includes('4 failures'));
  const tab = JR.render(ex, store, {});
  const buttons = []; walk(tab, (n) => { if (n.t === 'button' && n.a.role === 'tab') buttons.push(n); });
  buttons[1].a.on.click();
  const t = drawText(ex, store);
  assert.ok(t.includes('8.6 s') && !t.includes('4 failures'));
});
check('toggleState + $cond label (Button example 2)', () => {
  const ex = JR.ui.byName('Button').examples[1].spec, store = E.createStore(ex.state);
  assert.ok(drawText(ex, store).includes('Pause'));
  find(JR.render(ex, store, {}), (n) => n.t === 'button').a.on.click();
  assert.equal(store.get('/running'), false);
  assert.ok(drawText(ex, store).includes('Resume'));
});
check('setState (Card example 2)', () => {
  const ex = JR.ui.byName('Card').examples[1].spec, store = E.createStore(ex.state);
  const btns = []; walk(JR.render(ex, store, {}), (n) => { if (n.t === 'button') btns.push(n); });
  btns[0].a.on.click();
  assert.equal(store.get('/status'), 'Re-running 4 tests...');
});
check('repeat + removeState with $index (Table example 2)', () => {
  const ex = JR.ui.byName('Table').examples[1].spec, store = E.createStore(ex.state);
  assert.equal(store.get('/suites').length, 3);
  const btns = []; walk(JR.render(ex, store, {}), (n) => { if (n.t === 'button' && JR.vtext(n) === 'Dismiss') btns.push(n); });
  assert.equal(btns.length, 3, 'one Button per row');
  btns[1].a.on.click();
  assert.deepEqual(store.get('/suites').map((s) => s.name), ['CanvasBoardStateTests', 'MDXBlockScannerTests']);
});
check('$template reads the repeat item first (Grid example)', () => {
  const ex = JR.ui.byName('Grid').examples[0].spec, store = E.createStore(ex.state);
  assert.ok(drawText(ex, store).includes('4 failing of 61'));
});
check('$bindState on a chart selection writes state', () => {
  const ex = JR.ui.byName('BarChart').examples[0].spec, store = E.createStore(ex.state);
  const col = find(JR.render(ex, store, {}), (n) => n.a && n.a.role === 'button');
  col.a.on.click();
  assert.equal(store.get('/picked'), '4208');
  assert.ok(drawText(ex, store).includes('Selected run: 4208'));
});
check('nested repeat resolves { $item } against the enclosing scope', () => {
  const spec = { root: 'o', elements: { o: { type: 'Stack', props: {}, children: ['i'], repeat: { statePath: '/groups' } }, i: { type: 'Stack', props: {}, children: ['t'], repeat: { statePath: { $item: 'tests' } } }, t: { type: 'Text', props: { text: { $item: 'name' } } } }, state: { groups: [{ tests: [{ name: 'a1' }, { name: 'a2' }] }, { tests: [{ name: 'b1' }] }] } };
  assert.equal(drawText(spec, E.createStore(spec.state)), 'a1a2b1');
});
check('$bindItem writes to repeatBasePath/field', () => {
  const spec = { root: 'o', elements: { o: { type: 'Stack', props: {}, children: ['s'], repeat: { statePath: '/rows' } }, s: { type: 'Switch', props: { label: 'on', checked: { $bindItem: 'muted' } } } }, state: { rows: [{ muted: false }, { muted: false }] } };
  const store = E.createStore(spec.state);
  const sw = []; walk(JR.render(spec, store, {}), (n) => { if (n.t === 'input') sw.push(n); });
  sw[1].a.on.change({ target: { checked: true } });
  assert.deepEqual(store.get('/rows'), [{ muted: false }, { muted: true }]);
});
check('visible operators: eq neq gt gte lt lte not $and $or', () => {
  const ctx = { state: { n: 5, s: 'a' } };
  const t = (c) => E.evalCond(c, ctx);
  assert.ok(t({ $state: '/n', gt: 4 }) && t({ $state: '/n', gte: 5 }) && t({ $state: '/n', lt: 6 }) && t({ $state: '/n', lte: 5 }) && t({ $state: '/s', eq: 'a' }) && t({ $state: '/s', neq: 'b' }) && t({ $state: '/n', not: true, eq: 6 }));
  assert.ok(t([{ $state: '/n' }, { $state: '/s' }]) && !t({ $and: [{ $state: '/n' }, { $state: '/zzz' }] }) && t({ $or: [{ $state: '/zzz' }, { $state: '/s' }] }));
});
check('setByPath refuses __proto__ and never leaves holes', () => {
  assert.throws(() => E.setAt({}, '/__proto__/x', 1));
  assert.deepEqual(E.setAt({ a: [1] }, '/a/-', 2), { a: [1, 2] });
});
check('SpecStream: JSON Patch ops add replace remove move copy test', () => {
  let d = { a: { b: 1 }, l: [1, 2] };
  d = E.applyPatch(d, { op: 'add', path: '/l/-', value: 3 });
  d = E.applyPatch(d, { op: 'replace', path: '/a/b', value: 2 });
  d = E.applyPatch(d, { op: 'copy', from: '/a/b', path: '/c' });
  d = E.applyPatch(d, { op: 'move', from: '/c', path: '/d' });
  d = E.applyPatch(d, { op: 'remove', path: '/l/0' });
  E.applyPatch(d, { op: 'test', path: '/d', value: 2 });
  assert.deepEqual(d, { a: { b: 2 }, l: [2, 3], d: 2 });
  assert.throws(() => E.applyPatch(d, { op: 'test', path: '/d', value: 9 }));
  const p = E.parseSpecStream('{"op":"add","path":"/x","value":1}\nnot json\n{"op":"add","path"');
  assert.equal(p.patches.length, 1); assert.equal(p.bad.length, 1);
});

/* ---------- 5. streaming ---------- */
JR.streams.forEach((s) => {
  check(`stream "${s.id}": every prefix renders; y-domain only grows; final spec is whole`, () => {
    const items = s.lines.map((raw) => { try { return { patch: JSON.parse(raw) }; } catch { return { bad: true }; } });
    let spec = { elements: {} }; const domains = {}; let prevDomain = 0, sawSkeleton = false, sawBad = false;
    for (let i = 0; i <= items.length; i++) {
      if (i > 0) { if (items[i - 1].bad) sawBad = true; else spec = E.applyPatch(spec, items[i - 1].patch); }
      const done = i === items.length;
      const store = E.createStore(spec.state);
      const html = JR.toHTML(JR.render(spec, store, { streaming: !done, strict: true, domains, domainNote: () => '' }));
      assert.ok(html.length > 10);
      if (/sk live/.test(html)) sawSkeleton = true;
      const d = Object.values(domains)[0] || 0;
      if (!done) { assert.ok(d >= prevDomain, 'domain shrank at line ' + i); prevDomain = d; }
    }
    assert.deepEqual(E.danglingIds(spec), [], 'dangling ids at the end');
    assert.ok(sawSkeleton, 'skeletons appear for children that have not arrived');
    if (s.id === 'tests') assert.ok(sawBad, 'transcript includes a malformed line');
    if (s.domain) {
      assert.ok(prevDomain >= 60, 'domain grew to cover the spike (got ' + prevDomain + ')');
      const settled = {}; JR.render(spec, E.createStore(spec.state), { streaming: false, domains: settled, strict: true });
      assert.deepEqual(settled, {}, 'after the stream the domain is natural, not the streamed maximum');
    }
    const pts = E.getAt(spec, '/elements/chart/props/data');
    if (s.id === 'chart') { assert.equal(pts.length, 14); assert.equal(pts[9].secs, 36); }
  });
});

/* ---------- 6. Treemap ---------- */
check('Treemap layout tiles the rectangle exactly with no overlap, largest first', () => {
  const items = [41, 16, 13, 8, 6, 5, 3, 2, 2, 1].map((value, i) => ({ value, label: 'c' + i }));
  const rect = { x: 0, y: 0, w: 240, h: 120 }, cells = JR.squarify(items, rect);
  assert.equal(cells.length, items.length);
  const area = cells.reduce((s, c) => s + c.w * c.h, 0);
  assert.ok(Math.abs(area - 240 * 120) < 1e-6, 'area ' + area);
  cells.forEach((c) => { assert.ok(c.x >= -1e-9 && c.y >= -1e-9 && c.x + c.w <= 240 + 1e-9 && c.y + c.h <= 120 + 1e-9, 'inside'); });
  for (let i = 0; i < cells.length; i++) for (let j = i + 1; j < cells.length; j++) {
    const a = cells[i], b = cells[j];
    const ox = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x), oy = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    assert.ok(ox <= 1e-9 || oy <= 1e-9, 'overlap ' + i + ' ' + j);
  }
  cells.forEach((c) => assert.ok(Math.abs(c.w * c.h - (c.item.value / 97) * 240 * 120) < 1e-6, 'area proportional to value'));
});

/* ---------- 7. links, references, hygiene, size ---------- */
function walkFiles(dir, out = []) {
  fs.readdirSync(dir, { withFileTypes: true }).forEach((d) => { const p = path.join(dir, d.name); if (d.isDirectory()) walkFiles(p, out); else out.push(p); });
  return out;
}
const files = walkFiles(SITE);
const htmlFiles = files.filter((f) => f.endsWith('.html'));
const names = new Set(comps.map((c) => c.name));
const staticIds = (file) => new Set([...fs.readFileSync(file, 'utf8').matchAll(/\sid="([^"]+)"/g)].map((m) => m[1]));
const DYNAMIC_IDS = { 'component.html': new Set(['preview', 'variants', 'props', 'spec', 'swiftui']) };
let linkCount = 0;

function checkRef(from, ref, kind) {
  if (/^(https?:|mailto:|data:|javascript:)/.test(ref)) return;
  if (ref.startsWith('#') && ref.length === 1) return;
  linkCount++;
  const [beforeHash, hash] = ref.split('#');
  const [rel, query] = beforeHash.split('?');
  const target = rel === '' ? from : path.resolve(path.dirname(from), rel);
  assert.ok(fs.existsSync(target) && fs.statSync(target).isFile(), `${kind} ${ref} in ${path.basename(from)} -> missing file`);
  if (query) { const m = /(?:^|&)c=([^&]+)/.exec(query); if (m) assert.ok(names.has(decodeURIComponent(m[1])), `${ref} in ${path.basename(from)}: unknown component`); }
  if (hash && target.endsWith('.html')) {
    const base = path.basename(target);
    assert.ok(staticIds(target).has(hash) || (DYNAMIC_IDS[base] && DYNAMIC_IDS[base].has(hash)), `${ref} in ${path.basename(from)}: no id "${hash}" in ${base}`);
  }
}
htmlFiles.forEach((f) => {
  check(`links: ${path.basename(f)}`, () => {
    const html = fs.readFileSync(f, 'utf8');
    [...html.matchAll(/\s(?:href|src)="([^"]*)"/g)].forEach((m) => checkRef(f, m[1], 'ref'));
    assert.ok(!/<script[^>]+src="https?:/.test(html), 'no CDN scripts');
    assert.ok(/<html lang="/.test(html) && /name="viewport"/.test(html), 'lang and viewport');
    assert.ok(!/<img(?![^>]*\balt=)/.test(html), 'img without alt');
  });
});
files.filter((f) => f.endsWith('.js') && !f.includes(path.sep + 'tests' + path.sep) && !f.includes(path.sep + 'tools' + path.sep)).forEach((f) => {
  check(`links in script: ${path.basename(f)}`, () => {
    const src = fs.readFileSync(f, 'utf8');
    [...src.matchAll(/['"]((?:[A-Za-z0-9_.\/-]+)\.html(?:[?#][^'"]*)?)['"]/g)].forEach((m) => checkRef(path.join(SITE, 'index.html'), m[1], 'script link'));
  });
});
check('links: sidebar and prev/next links resolve for every component', () => {
  comps.forEach((c) => checkRef(at('index.html'), JR.ui.href(c.name), 'component link'));
});
check('hygiene: no API key strings, no local absolute paths', () => {
  const bad = [
    new RegExp('(^|[^A-Za-z0-9_])s' + 'k-[A-Za-z0-9]'),
    new RegExp('/Us' + 'ers/'),
    new RegExp('/pri' + 'vate/tmp'),
    new RegExp('/var/fol' + 'ders/')
  ];
  files.forEach((f) => {
    if (/\.(png|jpg|ico|woff2?)$/.test(f)) return;
    const txt = fs.readFileSync(f, 'utf8');
    bad.forEach((re) => assert.ok(!re.test(txt), `${path.relative(SITE, f)} matches ${re.source}`));
  });
});
check('hygiene: no network calls from site scripts (no fetch, XHR, WebSocket, eval)', () => {
  files.filter((f) => f.endsWith('.js') && f.includes(path.sep + 'js' + path.sep)).forEach((f) => {
    const src = fs.readFileSync(f, 'utf8');
    assert.ok(!/\bfetch\s*\(|XMLHttpRequest|WebSocket|\beval\s*\(|new Function\s*\(|\.innerHTML\s*=|document\.write/.test(src), path.basename(f));
  });
});
check('size: site is under 2 MB', () => {
  const total = files.reduce((s, f) => s + fs.statSync(f).size, 0);
  assert.ok(total < 2 * 1024 * 1024, total + ' bytes');
  console.log(`   site size: ${(total / 1024).toFixed(0)} KB in ${files.length} files`);
});

/* ---------- report ---------- */
console.log(`components in registry: ${comps.length} (standard ${comps.filter((c) => c.catalog === 'standard').length}, charts ${comps.filter((c) => c.catalog === 'charts').length}, Rafu ${comps.filter((c) => c.catalog === 'rafu').length})`);
console.log(`examples rendered: ${rendered}; variants rendered: ${variantsRendered}; handlers run: ${handlersRun}; internal links checked: ${linkCount}`);
console.log(`checks passed: ${passed}; failed: ${failures.length}`);
if (failures.length) { failures.forEach((f) => console.log('  FAIL ' + f)); process.exit(1); }
console.log('OK');
