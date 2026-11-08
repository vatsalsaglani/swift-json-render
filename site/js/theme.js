/* Theme page: presets, token swatches, contrast check, and the six customisation layers with live demos. */
(function (g) {
  'use strict';
  var JR = g.JR, ui = JR.ui, E = JR.engine, h = JR.h, doc = g.document, el = ui.el;
  var $ = function (id) { return doc.getElementById(id); };

  var PRESETS = [
    { id: 'native', label: 'Native', cls: '', note: 'macOS system colours. Follows the page light or dark mode.' },
    { id: 'hc', label: 'High contrast', cls: 't-hc', note: '2 pt hairlines at full opacity. Muted text steps up. Follows light or dark.' },
    { id: 'indigo', label: 'Rafu Indigo', cls: 't-indigo', note: 'A fixed dark palette with an amber accent. It does not follow the page theme.' },
    { id: 'khadi', label: 'Rafu Khadi', cls: 't-khadi', note: 'A fixed warm light palette with an ochre accent. It does not follow the page theme.' }
  ];
  var preset = PRESETS[0];

  var FAILURES = [{ name: 'CanvasBoardStateTests', failed: 4 }, { name: 'VoiceSessionTests', failed: 2 }, { name: 'MDXBlockScannerTests', failed: 1 }];
  var BTN = function (label, extra, on) { return { type: 'Button', props: Object.assign({ label: label }, extra), on: on }; };

  var MAIN = {
    root: 'card',
    elements: {
      card: { type: 'Card', props: { title: 'Failing tests by suite', description: 'main · run 4213' }, children: ['stats', 'table', 'alert', 'form', 'chart', 'actions'] },
      stats: { type: 'Grid', props: { columns: 3 }, children: ['s1', 's2', 's3'] },
      s1: { type: 'Stat', props: { label: 'Failing', value: '7', delta: '+3', intent: 'risk' } },
      s2: { type: 'Stat', props: { label: 'Tests', value: '1,284', delta: '+12', intent: 'good' } },
      s3: { type: 'Stat', props: { label: 'Wall time', value: '41', unit: 's', delta: '±0' } },
      table: { type: 'Table', props: { columns: [{ key: 'name', label: 'Suite' }, { key: 'failed', label: 'Failed', align: 'right' }], rows: { $state: '/suites' } } },
      alert: { type: 'Alert', props: { title: '3 warnings', text: 'Unused variable in CanvasBoardState.swift:212', type: 'warning' } },
      form: { type: 'Stack', props: { gap: 'md' }, children: ['branch', 'push'] },
      branch: { type: 'Input', props: { label: 'Branch name', value: { $bindState: '/branch' } } },
      push: { type: 'Switch', props: { label: 'Push after create', checked: { $bindState: '/push' } } },
      chart: { type: 'BarChart', props: { data: { $state: '/runs' }, x: 'run', y: 'n', series: 'result', layout: 'stacked', height: 'compact' } },
      actions: { type: 'Stack', props: { direction: 'horizontal', gap: 'sm' }, children: ['b1', 'b2', 'b3'] },
      b1: BTN('Re-run failing', { variant: 'primary', size: 'sm' }), b2: BTN('Open file', { size: 'sm' }), b3: BTN('Delete', { variant: 'destructive', size: 'sm' })
    },
    state: { suites: FAILURES, branch: 'feature/json-render-card', push: true, runs: [['4209', 'Passed', 62], ['4209', 'Failed', 5], ['4210', 'Passed', 64], ['4210', 'Failed', 4], ['4211', 'Passed', 63], ['4211', 'Failed', 7], ['4212', 'Passed', 66], ['4212', 'Failed', 3]].map(function (r) { return { run: r[0], result: r[1], n: r[2] }; }) }
  };

  var VARIANTS = {
    root: 'col',
    elements: {
      col: { type: 'Stack', props: { gap: 'md' }, children: ['cards', 'btns'] },
      cards: { type: 'Grid', props: { columns: 3, gap: 'sm' }, children: ['c1', 'c2', 'c3'] },
      c1: { type: 'Card', props: { title: 'plain', variant: 'plain' }, children: ['t'] },
      c2: { type: 'Card', props: { title: 'outlined', variant: 'outlined' }, children: ['t'] },
      c3: { type: 'Card', props: { title: 'elevated', variant: 'elevated' }, children: ['t'] },
      t: { type: 'Text', props: { text: 'Card', variant: 'muted' } },
      btns: { type: 'Stack', props: { direction: 'horizontal', gap: 'sm', align: 'center' }, children: ['p', 's', 'd', 'g', 'sm', 'lg'] },
      p: BTN('primary', { variant: 'primary' }), s: BTN('secondary', {}), d: BTN('destructive', { variant: 'destructive' }), g: BTN('plain', { variant: 'plain' }),
      sm: BTN('sm', { size: 'sm' }), lg: BTN('lg', { size: 'lg' })
    }
  };

  var STYLE = {
    root: 'card',
    elements: {
      card: { type: 'Card', props: { title: 'Failing tests by suite' }, children: ['stat', 'row'] },
      stat: { type: 'Stat', props: { label: 'Failing', value: '7', delta: '+3', intent: 'risk' } },
      row: { type: 'Stack', props: { direction: 'horizontal', gap: 'sm' }, children: ['a', 'b'] },
      a: BTN('Re-run failing', { variant: 'primary', size: 'sm' }), b: BTN('Open', { size: 'sm' })
    }
  };

  var SLOTS = {
    root: 'card',
    elements: {
      card: { type: 'Card', props: { title: 'Failures' }, children: ['table'], slots: { header: ['badge'], footer: ['rerun', 'open'] } },
      badge: { type: 'Badge', props: { text: 'main', variant: 'outline' } },
      table: { type: 'Table', props: { columns: ['name', 'failed'], rows: { $state: '/none' } }, slots: { empty: ['none'] } },
      none: { type: 'Text', props: { text: 'No failures. Nice.', variant: 'muted' } },
      rerun: BTN('Re-run', { variant: 'primary', size: 'sm' }), open: BTN('Open', { size: 'sm' })
    },
    state: { none: [] }
  };

  var OVERRIDE = {
    root: 'card',
    elements: {
      card: { type: 'Card', props: {}, children: ['table'] },
      table: { type: 'Table', props: { columns: [{ key: 'name', label: 'Suite' }, { key: 'failed', label: 'Failed', align: 'right' }] }, children: ['rm'], repeat: { statePath: '/suites', key: 'name' } },
      rm: { type: 'Button', props: { label: 'Dismiss', size: 'sm', variant: 'plain' }, on: { press: { action: 'removeState', params: { statePath: '/suites', index: { $index: true } } } } }
    },
    state: { suites: FAILURES }
  };

  /* the replacement view for Table: same props, rows, children and emit */
  function ChipTable(p, k) {
    return h('ul', { class: 'ovl' }, (k.rows || []).map(function (r) {
      return h('li', { class: 'ovl-row' }, h('span', { class: 'jr-chip' }, r.item.name + ' · ' + r.item.failed), h('span', { class: 'jr-row' }, r.kids));
    }));
  }

  /* ---------- colour roles and contrast ---------- */
  var ROLES = [
    ['color.surface (window)', '--m-bg', 'windowBackgroundColor'], ['color.surface (card)', '--m-card', 'windowBackgroundColor'], ['color.surfaceRaised', '--m-field', 'controlBackgroundColor'],
    ['color.text', '--m-fg', 'labelColor'], ['color.textMuted', '--m-muted', 'secondaryLabelColor'], ['color.hairline', '--m-line', 'separatorColor'],
    ['color.accent', '--m-accent', 'controlAccentColor'], ['color.onAccent', '--m-on-accent', 'white'], ['color.good', '--m-good', 'systemGreen'], ['color.warning', '--m-warn', 'systemOrange'], ['color.critical', '--m-risk', 'systemRed']
  ];
  function hex(c) {
    c = String(c).trim();
    var m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(c);
    if (!m) return null;
    var s = m[1].length === 3 ? m[1].replace(/./g, '$&$&') : m[1];
    return [parseInt(s.slice(0, 2), 16), parseInt(s.slice(2, 4), 16), parseInt(s.slice(4, 6), 16)];
  }
  function lum(rgb) {
    var v = rgb.map(function (x) { x /= 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4); });
    return 0.2126 * v[0] + 0.7152 * v[1] + 0.0722 * v[2];
  }
  function ratio(a, b) { var la = lum(a), lb = lum(b), hi = Math.max(la, lb), lo = Math.min(la, lb); return (hi + 0.05) / (lo + 0.05); }

  function colours() {
    var cs = g.getComputedStyle($('main-mock')), out = {};
    ROLES.forEach(function (r) { out[r[1]] = cs.getPropertyValue(r[1]).trim(); });
    return out;
  }
  function refreshColours() {
    var c = colours(), sw = $('swatches');
    sw.textContent = '';
    ROLES.forEach(function (r) {
      sw.appendChild(el('div', { class: 'swatch' }, [el('i', { style: 'background:' + c[r[1]] }), el('div', { style: 'min-width:0' }, [el('span', { text: r[0] }), el('small', { text: c[r[1]].toUpperCase() })])]));
    });
    var card = hex(c['--m-card']), checks = [['text on surface', hex(c['--m-fg']), card, 4.5], ['muted text on surface', hex(c['--m-muted']), card, 4.5], ['onAccent on accent', hex(c['--m-on-accent']), hex(c['--m-accent']), 3], ['accent on surface', hex(c['--m-accent']), card, 3]];
    var box = $('contrast');
    box.textContent = '';
    checks.forEach(function (ck) {
      if (!ck[1] || !ck[2]) return;
      var r = ratio(ck[1], ck[2]), ok = r >= ck[3];
      box.appendChild(el('span', { class: 'cbadge ' + (ok ? 'ok' : 'bad') }, [(ok ? '✓ ' : '× ') + ck[0] + ' ' + r.toFixed(1) + ':1', el('span', { class: 'muted', text: ' (needs ' + ck[3] + ')' })]));
    });
  }

  function tokensTable() {
    var tb = $('tokens').tBodies[0];
    var rows = [
      ['color.*', 'see the swatches above', 'Status colours always come with an icon and a word.'],
      ['type.caption … type.display', '11 / 12 / 13 / 15 / 20 / 28 pt', 'System font. Tabular digits in Stat and Table.'],
      ['space.1 … space.6', '4 / 8 / 12 / 16 / 20 / 32 pt', 'Card padding 12, stack gap 10 (sm 6, lg 16), section gap 20.'],
      ['radius.control / field / card', '7 / 8 / 12 pt', 'Matches Rafu RafuMetrics. Continuous corners.'],
      ['elevation.card', 'none (hairline)', 'The elevated variant adds one shadow: radius 8, y 2.'],
      ['motion.reveal', 'fade 180 ms ease-out', 'Streaming reveal only. Zero under Reduce Motion.'],
      ['control.size', '.regular', 'sm maps to .small, lg to .large.']
    ];
    rows.forEach(function (r) { tb.appendChild(el('tr', null, [el('td', null, [el('code', { text: r[0] })]), el('td', { text: r[1] }), el('td', { text: r[2] })])); });
  }

  /* ---------- wiring ---------- */
  var mocks = [];
  function applyPreset(p) {
    preset = p;
    mocks.forEach(function (m) {
      m.className = 'mock' + (p.cls ? ' ' + p.cls : '') + (m.getAttribute('data-style') === 'rafu' ? ' style-rafu' : '');
    });
    [].forEach.call($('presets').children, function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-id') === p.id ? 'true' : 'false'); });
    $('preset-note').textContent = p.note;
    refreshColours();
  }

  ui.ready(function () {
    ui.initTheme(); ui.initKeys();
    var presets = $('presets');
    PRESETS.forEach(function (p) {
      var b = el('button', { type: 'button', 'aria-pressed': 'false', 'data-id': p.id, text: p.label });
      b.addEventListener('click', function () { applyPreset(p); });
      presets.appendChild(b);
    });
    tokensTable();
    ui.live($('main-body'), E.clone(MAIN), {});
    ui.live($('la-body'), E.clone(STYLE), {});
    ui.live($('lb-body'), E.clone(VARIANTS), {});
    ui.live($('lc-body'), E.clone(STYLE), {});
    ui.live($('ld-body'), E.clone(SLOTS), {});
    /* layer e: one store, two renderers */
    var store = E.createStore(OVERRIDE.state), spec = E.clone(OVERRIDE);
    function drawBoth() {
      JR.mount($('le1-body'), JR.render(spec, store, {}));
      JR.mount($('le2-body'), JR.render(spec, store, { overrides: { Table: ChipTable } }));
    }
    store.subscribe(drawBoth); drawBoth();

    mocks = [].slice.call(doc.querySelectorAll('.mock'));
    ui.enhanceCodeBoxes();

    $('radius').addEventListener('input', function (e) {
      var v = e.target.value;
      $('radius-out').textContent = v + ' pt';
      $('la-mock').style.setProperty('--m-radius-card', v + 'px');
    });
    $('style-toggle').addEventListener('change', function (e) {
      if (e.target.checked) $('lc-mock').setAttribute('data-style', 'rafu'); else $('lc-mock').removeAttribute('data-style');
      applyPreset(preset);
    });
    applyPreset(PRESETS[0]);

    /* swatches follow the page theme for native and high contrast */
    var mq = g.matchMedia ? g.matchMedia('(prefers-color-scheme: dark)') : null;
    if (mq && mq.addEventListener) mq.addEventListener('change', refreshColours);
    new g.MutationObserver(refreshColours).observe(doc.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
    $('theme-toggle').addEventListener('click', function () { g.setTimeout(refreshColours, 0); });
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
