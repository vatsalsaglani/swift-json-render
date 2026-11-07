/* Shared page behaviour: theme toggle, copy buttons, code boxes, live specs, variants, Swift catalog snippets. */
(function (g) {
  'use strict';
  var JR = (g.JR = g.JR || {});
  var h = JR.h, E = JR.engine;
  var ui = (JR.ui = {});
  var doc = g.document;

  /* ---------- theme: auto / light / dark ---------- */
  var KEY = 'jr-theme';
  function stored() { try { return g.localStorage.getItem(KEY); } catch (e) { return null; } }
  function save(v) { try { if (v) g.localStorage.setItem(KEY, v); else g.localStorage.removeItem(KEY); } catch (e) { /* file:// may block storage */ } }
  function applyTheme(v) {
    if (v === 'light' || v === 'dark') doc.documentElement.setAttribute('data-theme', v);
    else doc.documentElement.removeAttribute('data-theme');
  }
  ui.initTheme = function () {
    var cur = stored();
    applyTheme(cur);
    var btn = doc.getElementById('theme-toggle');
    if (!btn) return;
    function label() {
      var v = doc.documentElement.getAttribute('data-theme') || 'auto';
      btn.textContent = 'Theme: ' + v.charAt(0).toUpperCase() + v.slice(1);
      btn.setAttribute('aria-label', 'Colour theme: ' + v + '. Press to change.');
    }
    label();
    btn.addEventListener('click', function () {
      var v = doc.documentElement.getAttribute('data-theme') || 'auto';
      var next = v === 'auto' ? 'light' : v === 'light' ? 'dark' : 'auto';
      applyTheme(next === 'auto' ? null : next);
      save(next === 'auto' ? null : next);
      label();
    });
  };

  /* ---------- DOM helper ---------- */
  ui.el = function (tag, props, kids) {
    var e = doc.createElement(tag);
    Object.keys(props || {}).forEach(function (k) {
      if (k === 'class') e.className = props[k];
      else if (k === 'text') e.textContent = props[k];
      else if (k === 'on') Object.keys(props.on).forEach(function (ev) { e.addEventListener(ev, props.on[ev]); });
      else if (props[k] !== null && props[k] !== undefined && props[k] !== false) e.setAttribute(k, props[k] === true ? '' : props[k]);
    });
    [].concat(kids || []).forEach(function (c) { if (c !== null && c !== undefined) e.appendChild(typeof c === 'string' ? doc.createTextNode(c) : c); });
    return e;
  };

  /* ---------- copy + code ---------- */
  ui.copy = function (text, done) {
    function fallback() {
      var ta = doc.createElement('textarea');
      ta.value = text; ta.setAttribute('readonly', ''); ta.style.position = 'fixed'; ta.style.opacity = '0';
      doc.body.appendChild(ta); ta.select();
      var ok = false;
      try { ok = doc.execCommand('copy'); } catch (e) { ok = false; }
      doc.body.removeChild(ta);
      done(ok);
    }
    if (g.navigator && g.navigator.clipboard && g.isSecureContext) g.navigator.clipboard.writeText(text).then(function () { done(true); }, fallback);
    else fallback();
  };
  ui.codeBox = function (code, lang, opts) {
    opts = opts || {};
    var pre = doc.createElement('pre'), codeEl = doc.createElement('code');
    pre.appendChild(codeEl);
    pre.tabIndex = 0;
    pre.setAttribute('aria-label', (opts.label || 'Code') + (lang ? ', ' + lang : ''));
    JR.mount(codeEl, h('span', null, JR.highlight(code, lang)));
    var btn = ui.el('button', { class: 'copy', type: 'button', text: 'Copy', 'aria-label': 'Copy ' + (opts.label || 'code') });
    var status = ui.el('span', { class: 'sr-only', role: 'status' });
    btn.addEventListener('click', function () {
      ui.copy(code, function (ok) {
        btn.textContent = ok ? 'Copied' : 'Press Ctrl+C';
        status.textContent = ok ? 'Copied to the clipboard' : 'Copy failed';
        g.setTimeout(function () { btn.textContent = 'Copy'; status.textContent = ''; }, 1600);
      });
    });
    return ui.el('div', { class: 'codebox' }, [pre, btn, status]);
  };
  ui.enhanceCodeBoxes = function () {
    [].forEach.call(doc.querySelectorAll('[data-code]'), function (n) {
      var src = n.getAttribute('data-code-src') ? doc.getElementById(n.getAttribute('data-code-src')) : n;
      var box = ui.codeBox(src.textContent.replace(/^\n/, '').replace(/\s+$/, ''), n.getAttribute('data-lang') || '', { label: n.getAttribute('data-label') || 'code' });
      n.parentNode.replaceChild(box, n);
    });
  };

  /* ---------- live specs ---------- */
  ui.live = function (host, spec, opts) {
    opts = opts || {};
    var store = E.createStore(spec.state);
    var api = { store: store, spec: spec };
    function draw() {
      JR.mount(host, JR.render(api.spec, store, opts));
      if (opts.onDraw) opts.onDraw(store);
    }
    store.subscribe(draw);
    api.redraw = draw;
    draw();
    return api;
  };

  /* Variant spec: clone example 1 and merge the variant props into the first element of the component's type. */
  ui.variantSpec = function (comp, variant, example) {
    if (variant.spec) return E.clone(variant.spec);
    var s = E.clone((example || comp.examples[0]).spec);
    var ids = Object.keys(s.elements), target = null, i;
    for (i = 0; i < ids.length; i++) if (s.elements[ids[i]].type === comp.name) { target = s.elements[ids[i]]; break; }
    if (!target) { for (i = 0; i < ids.length; i++) if (s.elements[ids[i]].type === 'BarChart' && comp.name === 'Chart') { target = s.elements[ids[i]]; break; } }
    if (target) Object.keys(variant.props || {}).forEach(function (k) {
      var v = variant.props[k];
      if (v === null) delete target.props[k]; else target.props[k] = E.clone(v);
    });
    return s;
  };

  /* ---------- planned Swift catalog definition, generated from the registry ---------- */
  function swiftType(p) {
    var t = p.type, m = /^enum\((.*)\)$/.exec(t);
    if (m) return '.enum([' + m[1].split(' | ').map(function (v) { return JSON.stringify(v); }).join(', ') + ']' + (p.default !== null && p.default !== undefined ? ', default: ' + JSON.stringify(String(p.default)) : '') + ')';
    if (t === 'string') return '.string()';
    if (t === 'number') return '.number(' + (p.default !== null && p.default !== undefined ? 'default: ' + p.default : '') + ')';
    if (t === 'boolean') return '.bool(default: ' + (p.default ? 'true' : 'false') + ')';
    if (/^array/.test(t)) return '.array(.object())';
    return '.any()';
  }
  ui.swiftDef = function (c) {
    var lines = [c.name + ': .component(', '    description: ' + JSON.stringify(c.description) + ',', '    props: ['];
    c.props.forEach(function (p) { lines.push('        ' + JSON.stringify(p.name) + ': ' + swiftType(p) + ',' + (p.required ? '' : '  // optional')); });
    lines.push('    ],');
    if (c.slots && c.slots.length) lines.push('    slots: [' + c.slots.map(function (s) { return JSON.stringify(s); }).join(', ') + '],');
    lines.push('    events: [' + (c.events || []).map(function (s) { return JSON.stringify(s); }).join(', ') + '])');
    return lines.join('\n');
  };

  /* ---------- registry helpers ---------- */
  ui.registry = function () { return JR.registry; };
  ui.byName = function (name) {
    var r = JR.registry.components;
    for (var i = 0; i < r.length; i++) if (r[i].name === name) return r[i];
    return null;
  };
  ui.href = function (name) { return 'component.html?c=' + encodeURIComponent(name); };
  ui.groupOf = function (id) {
    return JR.registry.meta.groups.filter(function (x) { return x.id === id; })[0];
  };

  /* "/" focuses the first search box; ignored while typing. */
  ui.initKeys = function (extra) {
    doc.addEventListener('keydown', function (e) {
      var t = e.target, typing = t && (t.tagName === 'INPUT' || t.tagName === 'TEXTAREA' || t.tagName === 'SELECT' || t.isContentEditable);
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      if (e.key === '/' && !typing) {
        var s = doc.querySelector('[data-search]');
        if (s) { e.preventDefault(); s.focus(); s.select(); }
      } else if (extra && !typing) extra(e);
    });
  };

  ui.ready = function (fn) {
    if (doc.readyState === 'loading') doc.addEventListener('DOMContentLoaded', fn); else fn();
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
