/* Home page: hero demo, facts, quick start tabs, searchable component grid with live previews. */
(function (g) {
  'use strict';
  var JR = g.JR, ui = JR.ui, E = JR.engine, doc = g.document;

  var HERO = {
    root: 'card',
    elements: {
      card: { type: 'Card', props: { title: 'Failing tests by suite', description: { $template: '${/failing} suites failing · run ${/runs}' } }, children: ['stats', 'tabs'] },
      stats: { type: 'Grid', props: { columns: 3 }, children: ['s1', 's2', 's3'] },
      s1: { type: 'Stat', props: { label: 'Tests', value: { $state: '/tests' }, delta: '+12', intent: 'good' } },
      s2: { type: 'Stat', props: { label: 'Suites failing', value: { $state: '/failing' }, delta: '+3', intent: 'risk' } },
      s3: { type: 'Stat', props: { label: 'Wall time', value: '41', unit: 's', delta: '±0' } },
      tabs: { type: 'Tabs', props: { tabs: [{ value: 'suites', label: 'By suite' }, { value: 'about', label: 'About' }], value: { $bindState: '/tab' } }, children: ['table', 'about', 'rerun'] },
      table: { type: 'Table', props: { columns: [{ key: 'name', label: 'Suite' }, { key: 'failed', label: 'Failed', align: 'right' }] }, children: ['dismiss'], repeat: { statePath: '/suites', key: 'name' }, visible: { $state: '/tab', eq: 'suites' } },
      dismiss: { type: 'Button', props: { label: 'Dismiss', size: 'sm', variant: 'plain' }, on: { press: [{ action: 'removeState', params: { statePath: '/suites', index: { $index: true } } }, { action: 'incrementState', params: { statePath: '/failing', by: -1 } }] } },
      about: { type: 'Text', props: { text: 'Every element above is plain data. The buttons write state, and the numbers read it.', variant: 'muted' }, visible: { $state: '/tab', eq: 'about' } },
      rerun: { type: 'Button', props: { label: 'Re-run failing', variant: 'primary', size: 'sm' }, on: { press: { action: 'incrementState', params: { statePath: '/runs' } } } }
    },
    state: { tab: 'suites', tests: 1284, failing: 3, runs: 4213, suites: [{ name: 'CanvasBoardStateTests', failed: 4 }, { name: 'VoiceSessionTests', failed: 2 }, { name: 'MDXBlockScannerTests', failed: 1 }] }
  };

  function facts(reg) {
    var n = { standard: 0, charts: 0, rafu: 0 };
    reg.components.forEach(function (c) { n[c.catalog]++; });
    var rows = [[n.standard, 'standard components'], [n.charts, 'chart components'], [n.rafu, 'Rafu additions'], [6, 'layers of customisation'], [0, 'web views']];
    var host = doc.getElementById('facts');
    rows.forEach(function (r) { host.appendChild(ui.el('div', { class: 'fact' }, [ui.el('b', { text: String(r[0]) }), ui.el('span', { text: r[1] })])); });
  }

  function quickStart() {
    var tabs = [].slice.call(doc.querySelectorAll('#qs-tabs [role=tab]'));
    doc.getElementById('qs-spec-host').appendChild(ui.codeBox(JSON.stringify({ root: HERO.root, elements: HERO.elements, state: HERO.state }, null, 2), 'json', { label: 'hero spec' }));
    function select(tab) {
      tabs.forEach(function (t) {
        var on = t === tab;
        t.setAttribute('aria-selected', on ? 'true' : 'false');
        t.tabIndex = on ? 0 : -1;
        doc.getElementById(t.getAttribute('aria-controls')).hidden = !on;
      });
    }
    tabs.forEach(function (t, i) {
      t.addEventListener('click', function () { select(t); });
      t.addEventListener('keydown', function (e) {
        var d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
        if (!d) return;
        var n = tabs[(i + d + tabs.length) % tabs.length];
        select(n); n.focus(); e.preventDefault();
      });
    });
  }

  function preview(comp, host) {
    var s = E.clone(comp.examples[0].spec);
    ui.live(host, s, { dense: true });
  }

  function grid(reg) {
    var catalogs = doc.getElementById('catalogs'), chips = doc.getElementById('chips'), q = doc.getElementById('q'), count = doc.getElementById('count');
    var CATS = [
      { id: 'standard', title: 'Standard catalog', blurb: '36 components, the json-render shadcn set.' },
      { id: 'charts', title: 'Chart family', blurb: 'JSONRenderCharts: 15 components on Swift Charts. Optional.' },
      { id: 'rafu', title: 'Rafu catalog', blurb: 'Additions that only Rafu ships. Not part of the open-source standard catalog.' }
    ];
    var state = { group: 'all', text: '' }, cards = [];
    var io = 'IntersectionObserver' in g ? new g.IntersectionObserver(function (entries) {
      entries.forEach(function (en) {
        if (!en.isIntersecting) return;
        var c = cards.filter(function (x) { return x.el === en.target; })[0];
        if (c && !c.done) { c.done = true; preview(c.comp, c.prev); }
        io.unobserve(en.target);
      });
    }, { rootMargin: '300px' }) : null;

    CATS.forEach(function (cat) {
      var sec = ui.el('section', { class: 'cat' + (cat.id === 'rafu' ? ' rafu' : ''), 'aria-labelledby': 'cat-' + cat.id }), body = ui.el('div', { class: 'cgrid' });
      var head = ui.el('div', { class: 'cat-head' }, [ui.el('h3', { id: 'cat-' + cat.id, text: cat.title }), ui.el('span', { class: 'pill ' + (cat.id === 'rafu' ? 'warn' : cat.id === 'charts' ? 'good' : 'plain'), text: cat.id === 'rafu' ? 'Rafu only' : cat.id === 'charts' ? 'Optional module' : 'Core' }), ui.el('p', { text: cat.blurb })]);
      sec.appendChild(head); sec.appendChild(body); catalogs.appendChild(sec);
      reg.components.filter(function (c) { return c.catalog === cat.id; }).forEach(function (c) {
        var prev = ui.el('div', { class: 'prev', inert: true }, [ui.el('div', { class: 'mock' }, [ui.el('div')])]);
        var host = prev.firstChild.firstChild;
        var el = ui.el('article', { class: 'ccard', 'data-name': c.name, 'data-group': c.group }, [
          ui.el('h4', null, [ui.el('a', { href: ui.href(c.name), text: c.name }), ui.el('span', { class: 'tag', text: ui.groupOf(c.group).label })]),
          ui.el('p', { text: c.description }), prev]);
        body.appendChild(el);
        var rec = { el: el, comp: c, prev: host, done: false, hay: (c.name + ' ' + c.group + ' ' + ui.groupOf(c.group).label + ' ' + c.description + ' ' + c.swiftui).toLowerCase() };
        cards.push(rec);
        if (io) io.observe(el); else { rec.done = true; preview(c, host); }
      });
      cat.sec = sec;
    });

    var GROUP_CHIPS = [['all', 'All']].concat(reg.meta.groups.map(function (x) { return [x.id, x.label]; }));
    GROUP_CHIPS.forEach(function (gc) {
      var b = ui.el('button', { type: 'button', class: 'chip', 'aria-pressed': gc[0] === 'all' ? 'true' : 'false', text: gc[1], 'data-group': gc[0] });
      b.addEventListener('click', function () { state.group = gc[0]; update(); });
      chips.appendChild(b);
    });
    q.addEventListener('input', function () { state.text = q.value.trim().toLowerCase(); update(); });

    function update() {
      var words = state.text.split(/\s+/).filter(Boolean), shown = 0;
      [].forEach.call(chips.children, function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-group') === state.group ? 'true' : 'false'); });
      cards.forEach(function (r) {
        var ok = (state.group === 'all' || r.comp.group === state.group) && words.every(function (w) { return r.hay.indexOf(w) >= 0; });
        r.el.hidden = !ok;
        if (ok) { shown++; if (!r.done) { r.done = true; preview(r.comp, r.prev); } }
      });
      CATS.forEach(function (cat) { cat.sec.hidden = !cat.sec.querySelector('.ccard:not([hidden])'); });
      count.textContent = shown === 0 ? '' : shown === cards.length ? cards.length + ' components' : shown + ' of ' + cards.length + ' components';
      var none = doc.getElementById('none');
      if (!shown && !none) catalogs.appendChild(ui.el('div', { class: 'empty', id: 'none', text: 'No component matches. Try "chart", "form" or "table".' }));
      if (shown && none) none.remove();
    }
    update();
  }

  ui.ready(function () {
    ui.initTheme();
    ui.initKeys();
    var reg = JR.registry;
    facts(reg);
    ui.live(doc.getElementById('hero-body'), E.clone(HERO), {});
    ui.enhanceCodeBoxes();
    quickStart();
    grid(reg);
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
