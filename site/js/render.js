/* Mini json-render renderer: walks a flat spec and builds vnodes in the native macOS mock style.
   Standard catalog (36) and Rafu catalog components live here; charts live in charts.js. */
(function (g) {
  'use strict';
  var JR = (g.JR = g.JR || {});
  var h = JR.h, E = JR.engine;
  var C = (JR.components = {});

  function cx() {
    return Array.prototype.filter.call(arguments, Boolean).join(' ');
  }
  function note(msg) { return h('div', { class: 'jr-note', role: 'note' }, msg); }
  function px(n) { return n + 'px'; }
  function asList(v) { return Array.isArray(v) ? v : v === undefined || v === null ? [] : [v]; }
  function str(v, d) { return v === undefined || v === null ? (d === undefined ? '' : d) : String(v); }
  function pickKey(v, allowed, def) { return allowed.indexOf(v) >= 0 ? v : def; }
  function options(list) {
    return asList(list).map(function (o) {
      return typeof o === 'object' && o !== null ? { value: o.value, label: str(o.label, o.value), disabled: !!o.disabled, destructive: !!o.destructive } : { value: o, label: String(o) };
    });
  }

  var ICONS = { plus: '+', minus: '\u2212', xmark: '\u00d7', checkmark: '\u2713', 'arrow.clockwise': '\u21bb', 'arrow.right': '\u2192', play: '\u25b6', doc: '\u25a4', folder: '\u25ad', gear: '\u2699', trash: '\u2327', 'square.and.arrow.up': '\u21e7', 'chevron.right': '\u203a' };
  function glyph(name) { return ICONS[name] || '\u2022'; }

  /* ---------- skeletons ---------- */
  function sk(w, hh) { return h('span', { class: 'sk live ' + (hh || 'h10') + ' ' + (w || 'w100'), 'aria-hidden': 'true' }); }
  function skeletonFor(parentType) {
    if (parentType === 'Table') return h('div', { class: 'jr-skel jr-skel-table', 'aria-hidden': 'true' }, sk('w100', 'h14'), sk('w100', 'h14'), sk('w80', 'h14'));
    if (!parentType || parentType === 'Card' || parentType === 'Stack' || parentType === 'Tabs')
      return h('div', { class: 'jr-skel jr-skel-card', 'aria-hidden': 'true' }, sk('w60', 'h22'), sk('w100'), sk('w80'));
    return h('div', { class: 'jr-skel', 'aria-hidden': 'true' }, sk('w60'));
  }

  /* ---------- core walk ---------- */
  var MAX_DEPTH = 64, MAX_ELEMENTS = 2000, MAX_ROWS = 500;

  function repeatBase(rep, ctx) {
    var sp = rep.statePath;
    if (sp && typeof sp === 'object' && '$item' in sp) return (ctx.basePath || '') + '/' + String(sp.$item).replace(/\./g, '/');
    return String(sp);
  }

  function node(R, id, ctx, depth, path, parentType) {
    if (depth > MAX_DEPTH) return note('Too deep');
    if (path.indexOf(id) >= 0) return note('Cycle at ' + id);
    if (++R.count > MAX_ELEMENTS) return note('Too many elements');
    var el = R.spec.elements && R.spec.elements[id];
    if (!el) return R.opts.streaming ? skeletonFor(parentType) : note('Missing element ' + id);
    if (!E.evalCond(el.visible, ctx)) return null;
    var store = R.store, rp = E.resolveProps(el.props, ctx), P = path.concat(id);
    function build(c) {
      return asList(el.children).map(function (cid) { return node(R, cid, c, depth + 1, P, el.type); }).filter(Boolean);
    }
    var kids, rows = null, slots = {};
    if (el.repeat) {
      var base = repeatBase(el.repeat, ctx), arr = E.getAt(ctx.state, base);
      if (arr === undefined && R.opts.streaming) return skeletonFor(el.type === 'Table' ? 'Table' : null);
      arr = Array.isArray(arr) ? arr.slice(0, MAX_ROWS) : [];
      rows = arr.map(function (item, i) {
        var c2 = { state: ctx.state, item: item, index: i, basePath: base + '/' + i };
        return { item: item, index: i, ctx: c2, kids: build(c2) };
      });
      kids = [];
      rows.forEach(function (r) { kids = kids.concat(r.kids); });
    } else kids = build(ctx);
    Object.keys(el.slots || {}).forEach(function (s) {
      slots[s] = asList(el.slots[s]).map(function (cid) { return node(R, cid, ctx, depth + 1, P, el.type); }).filter(Boolean);
    });
    var ukey = id + ':' + (ctx.basePath || '');
    var k = {
      id: id, el: el, type: el.type, kids: kids, slots: slots, rows: rows, ctx: ctx, store: store, opts: R.opts,
      bindings: rp.bindings, h: h,
      emit: function (name) {
        var b = el.on && el.on[name];
        if (b) E.runAction(b, Object.assign({}, ctx, { state: store.state }), store);
      },
      local: function (name, def) {
        var key = 'ui:' + ukey + ':' + name;
        return [store.ui(key, def), function (v) { store.setUi(key, v); }];
      },
      model: function (prop, def) {
        var b = rp.bindings[prop], cur = rp.props[prop];
        if (b) return [cur === undefined ? def : cur, function (v) { store.set(b, v); }, true];
        var key = 'ui:' + ukey + ':' + prop;
        return [store.ui(key, cur === undefined ? def : cur), function (v) { store.setUi(key, v); }, false];
      },
      domain: function (max) {
        var d = R.opts.domains;
        if (!R.opts.streaming || !d) return max;
        d[id] = Math.max(d[id] || 0, max);
        return d[id];
      }
    };
    var fn = (R.opts.overrides && R.opts.overrides[el.type]) || C[el.type];
    if (!fn) return h('div', { class: 'jr-note' }, 'Unknown component ' + el.type);
    if (R.opts.strict) return fn(rp.props, k);
    try { return fn(rp.props, k); }
    catch (e) { return note(el.type + ': ' + e.message); }
  }

  function render(spec, store, opts) {
    opts = opts || {};
    var R = { spec: spec || {}, store: store, opts: opts, count: 0 };
    if (!spec || !spec.root) return opts.streaming ? skeletonFor(null) : note('Spec has no root');
    var ctx = { state: store.state, item: undefined, index: undefined, basePath: '' };
    return node(R, spec.root, ctx, 0, [], null) || h('div');
  }

  /* ---------- highlighting (vnode spans) ---------- */
  var LANGS = {
    json: /(?<key>"(?:\\.|[^"\\])*"(?=\s*:))|(?<str>"(?:\\.|[^"\\])*")|(?<num>-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|(?<kw>\btrue\b|\bfalse\b|\bnull\b)|(?<punc>[{}\[\],:])/g,
    swift: /(?<com>\/\/[^\n]*)|(?<str>"(?:\\.|[^"\\])*")|(?<kw>\b(?:import|struct|func|var|let|some|public|static|extension|protocol|associatedtype|return|try|await|async|throws|if|else|for|in|case|enum|class|init|self|true|false|nil|any|where|guard|switch|default|private|final)\b)|(?<ty>\b[A-Z][A-Za-z0-9_]*\b)|(?<num>\b\d+(?:\.\d+)?\b)|(?<at>@[A-Za-z_]+)/g,
    bash: /(?<com>#[^\n]*)|(?<str>"(?:\\.|[^"\\])*"|'[^']*')|(?<kw>\b(?:npx|swift|cd|git|node|python3)\b)|(?<at>--?[a-z][\w-]*)/g
  };
  function highlight(code, lang) {
    var re = LANGS[lang];
    if (!re) return [String(code)];
    var out = [], last = 0, m, s = String(code);
    re = new RegExp(re.source, 'g');
    while ((m = re.exec(s))) {
      if (m.index > last) out.push(s.slice(last, m.index));
      var cls = Object.keys(m.groups).filter(function (n) { return m.groups[n] !== undefined; })[0];
      out.push(h('span', { class: 'tk-' + cls }, m[0]));
      last = m.index + m[0].length;
      if (m[0].length === 0) re.lastIndex++;
    }
    if (last < s.length) out.push(s.slice(last));
    return out;
  }

  /* ---------- Layout ---------- */
  var GAPS = { none: 0, sm: 6, md: 10, lg: 16, xl: 24 };
  var WIDTHS = { sm: 320, md: 480, lg: 640 };

  C.Card = function (p, k) {
    var v = pickKey(p.variant, ['outlined', 'plain', 'elevated'], 'outlined');
    return h('div', { class: cx('jr-card', v === 'plain' && 'plain', v === 'elevated' && 'elev'), style: WIDTHS[p.maxWidth] ? 'max-width:' + px(WIDTHS[p.maxWidth]) : null },
      k.slots.header && k.slots.header.length ? h('div', { class: 'jr-slot' }, k.slots.header) : null,
      p.title ? h('div', { class: 'jr-title' }, str(p.title)) : null,
      p.subtitle ? h('div', { class: 'jr-sub' }, str(p.subtitle)) : null,
      k.kids,
      k.slots.footer && k.slots.footer.length ? h('div', { class: 'jr-row jr-slot' }, k.slots.footer) : null);
  };
  C.Stack = function (p, k) {
    var dir = p.direction === 'horizontal' ? 'row' : 'column';
    var gap = GAPS[p.gap] !== undefined ? GAPS[p.gap] : 10;
    var al = { start: 'flex-start', center: 'center', end: 'flex-end', stretch: 'stretch' }[p.align] || (dir === 'row' ? 'center' : null);
    return h('div', { class: 'jr-stack', style: 'flex-direction:' + dir + ';gap:' + px(gap) + (al ? ';align-items:' + al : '') + (p.wrap || dir === 'row' ? ';flex-wrap:wrap' : '') }, k.kids);
  };
  C.Grid = function (p, k) {
    var n = Math.max(1, Math.min(6, Number(p.columns) || 2)), gap = GAPS[p.gap] !== undefined ? GAPS[p.gap] : 10;
    return h('div', { class: 'jr-grid', style: 'grid-template-columns:repeat(' + n + ',minmax(0,1fr));gap:' + px(gap) }, k.kids);
  };
  C.Separator = function (p) {
    return h('div', { class: cx('jr-sep', p.orientation === 'vertical' && 'v'), role: 'separator', 'aria-orientation': p.orientation === 'vertical' ? 'vertical' : 'horizontal' });
  };
  C.Carousel = function (p, k) {
    var n = k.kids.length, m = k.local('index', 0), i = Math.min(m[0], Math.max(0, n - 1));
    function go(d) { m[1]((i + d + n) % n); }
    return h('div', { class: 'jr-carousel', role: 'group', 'aria-roledescription': 'carousel' },
      h('div', { class: 'jr-slide', 'aria-live': 'polite' }, k.kids[i]),
      n > 1 ? h('div', { class: 'jr-row jr-car-bar' },
        h('button', { class: 'jr-btn sm', 'aria-label': 'Previous slide', on: { click: function () { go(-1); } } }, '\u2039'),
        h('span', { class: 'jr-dots' }, k.kids.map(function (_, j) { return h('i', { class: j === i ? 'on' : null }); })),
        h('span', { class: 'jr-muted' }, (i + 1) + ' / ' + n),
        h('button', { class: 'jr-btn sm', 'aria-label': 'Next slide', on: { click: function () { go(1); } } }, '\u203a')) : null);
  };

  /* ---------- Content ---------- */
  C.Heading = function (p) {
    var lv = Number(String(p.level || 'h2').replace('h', '')) || 2;
    return h('div', { class: 'jr-h jr-h' + Math.min(4, Math.max(1, lv)), role: 'heading', 'aria-level': String(lv) }, str(p.text));
  };
  C.Text = function (p, k) {
    if (k.opts.streaming && (p.text === undefined || p.text === null)) return sk('w80');
    var v = pickKey(p.variant, ['body', 'caption', 'muted', 'lead', 'code'], 'body');
    return h('div', { class: 'jr-text ' + v }, str(p.text));
  };
  function host(src) { var m = /^https?:\/\/([^\/]+)/i.exec(String(src)); return m ? m[1] : null; }
  C.Image = function (p) {
    var w = Number(p.width) || null, hh = Number(p.height) || null;
    var style = (w ? 'width:' + px(w) + ';' : '') + (hh ? 'height:' + px(hh) + ';' : '');
    var src = str(p.src);
    if (/^data:image\/(png|jpeg|gif|webp|svg\+xml);/.test(src))
      return h('img', { class: 'jr-img', src: src, alt: str(p.alt), style: style + 'object-fit:' + pickKey(p.fit, ['cover', 'contain', 'fill'], 'cover') });
    var hostName = host(src);
    return h('div', { class: 'jr-img ph', style: style, role: 'img', 'aria-label': str(p.alt, 'Image') },
      h('div', { class: 'jr-imgbody' }, p.systemName ? h('span', { class: 'jr-bigglyph', 'aria-hidden': 'true' }, glyph(p.systemName)) : null,
        h('b', null, str(p.alt, 'Image')),
        hostName ? h('span', { class: 'jr-muted' }, 'Remote image from ' + hostName + '. Loads after one consent. The image host will see a request from this Mac.') : h('span', { class: 'jr-muted' }, 'Local file placeholder: ' + (src || 'no source'))));
  };
  C.Avatar = function (p) {
    var name = str(p.name, '?'), initials = name.split(/\s+/).filter(Boolean).slice(0, 2).map(function (s) { return s.charAt(0).toUpperCase(); }).join('');
    var sz = { sm: 22, md: 32, lg: 44 }[p.size] || 32;
    return h('span', { class: 'jr-avatar', style: 'width:' + px(sz) + ';height:' + px(sz) + ';font-size:' + Math.round(sz * 0.4) + 'px', role: 'img', 'aria-label': name }, initials);
  };
  var BADGE_ICON = { good: '\u2713 ', warning: '! ', critical: '\u00d7 ' };
  C.Badge = function (p) {
    var v = pickKey(p.variant, ['default', 'secondary', 'outline', 'good', 'warning', 'critical'], 'default');
    var cls = { good: 'good', warning: 'warn', critical: 'risk', secondary: 'sec', outline: 'out' }[v];
    return h('span', { class: cx('jr-badge', cls) }, BADGE_ICON[v] || '', str(p.text));
  };
  var ALERT = { info: ['info', 'i'], success: ['good', '\u2713'], warning: ['warn', '!'], error: ['risk', '\u00d7'] };
  C.Alert = function (p) {
    var a = ALERT[p.type] || ALERT.info;
    return h('div', { class: 'jr-alert ' + a[0], role: p.type === 'error' ? 'alert' : 'status' },
      h('span', { class: 'ic', 'aria-hidden': 'true' }, a[1]), h('div', null, p.title ? h('b', null, str(p.title)) : null, p.text ? h('span', null, str(p.text)) : null));
  };
  C.Link = function (p, k) {
    function go() { k.emit('press'); k.store.note({ action: 'open_url', params: { href: str(p.href) }, host: true }); k.store.notify(); }
    return h('span', { class: 'jr-link', role: 'link', tabindex: '0', title: 'Opens externally after host confirmation: ' + str(p.href),
      on: { click: go, keydown: function (e) { if (e.key === 'Enter') go(); } } }, str(p.text, p.href));
  };

  /* ---------- Form ---------- */
  function field(label, control) {
    return h('label', { class: 'jr-field' }, label ? h('span', { class: 'jr-flabel' }, str(label)) : null, control);
  }
  C.Button = function (p, k) {
    var v = pickKey(p.variant, ['secondary', 'primary', 'destructive', 'plain'], 'secondary');
    return h('button', { type: 'button', class: cx('jr-btn', v !== 'secondary' && v, p.size === 'sm' && 'sm', p.size === 'lg' && 'lg'),
      on: { click: function () { k.emit('press'); } }, p: { disabled: !!p.disabled } }, p.icon ? h('span', { 'aria-hidden': 'true' }, glyph(p.icon)) : null, str(p.label));
  };
  C.ButtonGroup = function (p, k) { return h('div', { class: 'jr-bgroup', role: 'group' }, k.kids); };
  C.Input = function (p, k) {
    var m = k.model('value', ''), type = pickKey(p.type, ['text', 'email', 'password', 'number'], 'text');
    return field(p.label, h('input', { class: 'jr-input', type: type, placeholder: p.placeholder || null, autocomplete: 'off', 'aria-label': p.label ? null : 'Input',
      p: { value: m[0] === undefined ? '' : m[0] }, on: { input: function (e) { m[1](type === 'number' && e.target.value !== '' ? Number(e.target.value) : e.target.value); k.emit('change'); } } }));
  };
  C.Textarea = function (p, k) {
    var m = k.model('value', '');
    return field(p.label, h('textarea', { class: 'jr-input', rows: String(p.rows || 3), placeholder: p.placeholder || null,
      p: { value: m[0] === undefined ? '' : m[0] }, on: { input: function (e) { m[1](e.target.value); k.emit('change'); } } }));
  };
  C.Select = function (p, k) {
    var m = k.model('value', ''), opts = options(p.options);
    return field(p.label, h('select', { class: 'jr-input', p: { value: m[0] === undefined ? '' : m[0] }, on: { change: function (e) { m[1](e.target.value); k.emit('change'); } } },
      p.placeholder ? h('option', { value: '', disabled: true }, p.placeholder) : null,
      opts.map(function (o) { return h('option', { value: String(o.value) }, o.label); })));
  };
  C.Checkbox = function (p, k) {
    var m = k.model('checked', false);
    return h('label', { class: 'jr-choice' }, h('input', { type: 'checkbox', p: { checked: !!m[0], disabled: !!p.disabled }, on: { change: function (e) { m[1](e.target.checked); k.emit('change'); } } }), str(p.label));
  };
  C.Radio = function (p, k) {
    var m = k.model('value', ''), opts = options(p.options), name = 'r-' + k.id + (k.ctx.basePath || '');
    return h('div', { class: 'jr-fieldset', role: 'radiogroup', 'aria-label': p.label || 'Options' },
      p.label ? h('span', { class: 'jr-flabel' }, str(p.label)) : null,
      opts.map(function (o) {
        return h('label', { class: 'jr-choice' }, h('input', { type: 'radio', name: name, value: String(o.value), p: { checked: m[0] === o.value }, on: { change: function () { m[1](o.value); k.emit('change'); } } }), o.label);
      }));
  };
  C.Switch = function (p, k) {
    var m = k.model('checked', false);
    return h('label', { class: 'jr-switch' }, h('input', { type: 'checkbox', role: 'switch', class: 'jr-sr', p: { checked: !!m[0], disabled: !!p.disabled }, on: { change: function (e) { m[1](e.target.checked); k.emit('change'); } } }), h('i', { 'aria-hidden': 'true' }), str(p.label));
  };
  C.Slider = function (p, k) {
    var m = k.model('value', 0), min = Number(p.min === undefined ? 0 : p.min), max = Number(p.max === undefined ? 100 : p.max);
    return field(p.label, h('span', { class: 'jr-slider' }, h('input', { type: 'range', min: String(min), max: String(max), step: String(p.step || 1), 'aria-label': p.label || 'Slider',
      p: { value: m[0] === undefined ? min : m[0] }, on: { input: function (e) { m[1](Number(e.target.value)); k.emit('change'); } } }), h('output', { class: 'jr-muted' }, str(m[0]))));
  };
  C.Toggle = function (p, k) {
    var m = k.model('pressed', false);
    return h('button', { type: 'button', class: cx('jr-btn', m[0] && 'on'), 'aria-pressed': m[0] ? 'true' : 'false', on: { click: function () { m[1](!m[0]); k.emit('change'); } } }, str(p.label));
  };
  C.ToggleGroup = function (p, k) {
    var multiple = p.type === 'multiple', m = k.model('value', multiple ? [] : ''), opts = options(p.options);
    function on(v) { return multiple ? asList(m[0]).indexOf(v) >= 0 : m[0] === v; }
    function click(v) {
      if (multiple) { var cur = asList(m[0]); m[1](cur.indexOf(v) >= 0 ? cur.filter(function (x) { return x !== v; }) : cur.concat([v])); }
      else m[1](v);
      k.emit('change');
    }
    return h('div', { class: 'jr-seg', role: 'group', 'aria-label': p.label || 'Options' }, opts.map(function (o) {
      return h('button', { type: 'button', class: on(o.value) ? 'on' : null, 'aria-pressed': on(o.value) ? 'true' : 'false', on: { click: function () { click(o.value); } } }, o.label);
    }));
  };

  /* ---------- Navigation ---------- */
  C.Tabs = function (p, k) {
    var tabs = options(p.tabs), m = k.model('value', tabs[0] && tabs[0].value), seg = p.variant === 'segmented';
    function key(e) {
      var d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (!d) return;
      var i = tabs.findIndex(function (t) { return t.value === m[0]; }), n = tabs[(i + d + tabs.length) % tabs.length];
      m[1](n.value);
      var list = e.currentTarget, btn = list && list.children[(i + d + tabs.length) % tabs.length];
      if (btn) btn.focus();
      e.preventDefault();
    }
    return h('div', { class: 'jr-tabwrap' },
      h('div', { class: seg ? 'jr-seg' : 'jr-tabs', role: 'tablist', on: { keydown: key } }, tabs.map(function (t) {
        var on = t.value === m[0];
        return h('button', { type: 'button', role: 'tab', class: cx(seg ? null : 'jr-tab', on && 'on'), 'aria-selected': on ? 'true' : 'false', tabindex: on ? '0' : '-1', on: { click: function () { m[1](t.value); k.emit('change'); } } }, t.label);
      })),
      h('div', { class: 'jr-stack', role: 'tabpanel', style: 'flex-direction:column;gap:10px;margin-top:10px' }, k.kids));
  };
  C.Accordion = function (p, k) {
    var items = options(p.items).map(function (o, i) { var src = asList(p.items)[i]; return { value: o.value !== undefined ? o.value : String(i), title: str(src.title, o.label), text: str(src.text) }; });
    var multiple = p.type === 'multiple', m = k.model('value', multiple ? [] : '');
    function open(v) { return multiple ? asList(m[0]).indexOf(v) >= 0 : m[0] === v; }
    function toggle(v) {
      if (multiple) { var cur = asList(m[0]); m[1](cur.indexOf(v) >= 0 ? cur.filter(function (x) { return x !== v; }) : cur.concat([v])); }
      else m[1](m[0] === v ? '' : v);
    }
    return h('div', { class: 'jr-acc' }, items.map(function (it) {
      var o = open(it.value);
      return h('div', { class: 'jr-acc-item' },
        h('button', { type: 'button', class: 'jr-acc-head', 'aria-expanded': o ? 'true' : 'false', on: { click: function () { toggle(it.value); } } }, h('span', { class: cx('jr-chev', o && 'open'), 'aria-hidden': 'true' }, '\u203a'), it.title),
        o ? h('div', { class: 'jr-acc-body' }, it.text) : null);
    }));
  };
  C.Collapsible = function (p, k) {
    var m = k.model('open', false);
    return h('div', { class: 'jr-acc' }, h('div', { class: 'jr-acc-item' },
      h('button', { type: 'button', class: 'jr-acc-head', 'aria-expanded': m[0] ? 'true' : 'false', on: { click: function () { m[1](!m[0]); } } }, h('span', { class: cx('jr-chev', m[0] && 'open'), 'aria-hidden': 'true' }, '\u203a'), str(p.title)),
      m[0] ? h('div', { class: 'jr-acc-body' }, k.kids) : null));
  };
  C.Pagination = function (p, k) {
    var m = k.model('page', 1), total = Math.max(1, Number(p.total) || 1), page = Math.min(Math.max(1, Number(m[0]) || 1), total);
    function go(n) { m[1](Math.min(total, Math.max(1, n))); k.emit('change'); }
    var from = Math.max(1, Math.min(page - 2, total - 4)), nums = [];
    for (var i = from; i <= Math.min(total, from + 4); i++) nums.push(i);
    return h('nav', { class: 'jr-pager', 'aria-label': 'Pagination', on: { keydown: function (e) { if (e.key === 'ArrowRight') go(page + 1); if (e.key === 'ArrowLeft') go(page - 1); } } },
      h('button', { type: 'button', class: 'jr-btn sm', disabled: page <= 1 ? true : null, 'aria-label': 'Previous page', on: { click: function () { go(page - 1); } } }, '\u2039 Prev'),
      nums.map(function (n) { return h('button', { type: 'button', class: cx('jr-btn sm', n === page && 'primary'), 'aria-current': n === page ? 'page' : null, on: { click: function () { go(n); } } }, String(n)); }),
      h('button', { type: 'button', class: 'jr-btn sm', disabled: page >= total ? true : null, 'aria-label': 'Next page', on: { click: function () { go(page + 1); } } }, 'Next \u203a'));
  };

  /* ---------- Overlay (rendered in flow so the mock never clips them) ---------- */
  function sheet(p, k, m, side) {
    if (!m[0]) return null;
    function close() { m[1](false); }
    return h('div', { class: cx('jr-overlay', side && 'side-' + side) },
      h('div', { class: cx('jr-sheet', side && 'drawer'), role: 'dialog', 'aria-modal': 'true', 'aria-label': p.title || 'Dialog', on: { keydown: function (e) { if (e.key === 'Escape') close(); } } },
        h('div', { class: 'jr-row jr-sheet-head' }, h('div', { class: 'jr-title' }, str(p.title)), h('button', { type: 'button', class: 'jr-btn sm plain', 'aria-label': 'Close', on: { click: close } }, '\u00d7')),
        k.kids));
  }
  C.Dialog = function (p, k) { return sheet(p, k, k.model('open', false), null) || h('div', { class: 'jr-closed', 'aria-hidden': 'true' }); };
  C.Drawer = function (p, k) { return sheet(p, k, k.model('open', false), p.side === 'left' ? 'left' : 'right') || h('div', { class: 'jr-closed', 'aria-hidden': 'true' }); };
  C.Tooltip = function (p, k) {
    return h('span', { class: 'jr-tip' }, k.kids, h('span', { class: 'jr-tip-bubble', role: 'tooltip' }, str(p.text)));
  };
  C.Popover = function (p, k) {
    var m = k.model('open', false);
    return h('div', { class: 'jr-popwrap' },
      h('span', { class: 'jr-poptrig', on: { click: function () { m[1](!m[0]); } } }, k.slots.trigger || []),
      m[0] ? h('div', { class: 'jr-pop', role: 'dialog', on: { keydown: function (e) { if (e.key === 'Escape') m[1](false); } } }, k.kids) : null);
  };
  C.DropdownMenu = function (p, k) {
    var o = k.local('open', false), v = k.model('value', null), items = options(p.items);
    return h('div', { class: 'jr-popwrap', on: { keydown: function (e) { if (e.key === 'Escape') o[1](false); } } },
      h('button', { type: 'button', class: 'jr-btn', 'aria-haspopup': 'menu', 'aria-expanded': o[0] ? 'true' : 'false', on: { click: function () { o[1](!o[0]); } } }, str(p.label, 'Menu'), ' \u25be'),
      o[0] ? h('div', { class: 'jr-menu', role: 'menu' }, items.map(function (it) {
        return h('button', { type: 'button', role: 'menuitem', class: cx('jr-menuitem', it.destructive && 'danger', v[0] === it.value && 'on'), disabled: it.disabled ? true : null,
          on: { click: function () { v[1](it.value); o[1](false); k.emit('select'); } } }, it.label);
      })) : null);
  };

  /* ---------- Data ---------- */
  function cell(v) { return v === undefined || v === null ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v); }
  C.Table = function (p, k) {
    var cols = asList(p.columns).map(function (c) { return typeof c === 'string' ? { key: c, label: c } : c; });
    var rows = k.rows
      ? k.rows.map(function (r) { return { item: r.item, extra: r.kids }; })
      : asList(p.rows).map(function (r) { return { item: r, extra: [] }; });
    var s = k.local('sort', null), sort = s[0];
    function val(r, c) { return Array.isArray(r.item) ? r.item[cols.indexOf(c)] : E.itemField({ item: r.item }, c.key); }
    if (sort) {
      var col = cols.filter(function (c) { return c.key === sort.key; })[0];
      if (col) rows = rows.slice().sort(function (a, b) {
        var x = val(a, col), y = val(b, col), d = typeof x === 'number' && typeof y === 'number' ? x - y : cell(x).localeCompare(cell(y));
        return sort.dir === 'desc' ? -d : d;
      });
    }
    var hasExtra = rows.some(function (r) { return r.extra.length; });
    return h('div', { class: 'jr-tablewrap' }, h('table', { class: 'jr-table' },
      h('thead', null, h('tr', null, cols.map(function (c) {
        var num = c.align === 'right', on = sort && sort.key === c.key;
        return h('th', { class: num ? 'num' : null, 'aria-sort': on ? (sort.dir === 'desc' ? 'descending' : 'ascending') : null },
          p.sortable ? h('button', { type: 'button', class: 'jr-thbtn', on: { click: function () { s[1](on && sort.dir === 'asc' ? { key: c.key, dir: 'desc' } : { key: c.key, dir: 'asc' }); } } }, str(c.label, c.key), on ? (sort.dir === 'desc' ? ' \u25bc' : ' \u25b2') : '') : str(c.label, c.key));
      }).concat(hasExtra ? [h('th', { 'aria-label': 'Actions' })] : []))),
      h('tbody', null, rows.length ? rows.map(function (r) {
        return h('tr', null, cols.map(function (c) {
          var v = val(r, c);
          return h('td', { class: c.align === 'right' || typeof v === 'number' ? 'num' : null }, cell(v));
        }).concat(hasExtra ? [h('td', { class: 'act' }, h('span', { class: 'jr-row' }, r.extra))] : []));
      }) : [h('tr', null, h('td', { colspan: String(cols.length + (hasExtra ? 1 : 0)), class: 'jr-muted' }, k.slots.empty && k.slots.empty.length ? k.slots.empty : str(p.emptyText, 'No rows')))])));
  };
  C.Progress = function (p) {
    var max = Number(p.max) || 100, v = Math.min(max, Math.max(0, Number(p.value) || 0)), pct = Math.round((v / max) * 100);
    return h('div', { class: 'jr-progwrap' }, p.label ? h('div', { class: 'jr-row between' }, h('span', { class: 'jr-muted' }, str(p.label)), h('span', { class: 'jr-muted num' }, pct + ' %')) : null,
      h('div', { class: 'jr-prog', role: 'progressbar', 'aria-valuemin': '0', 'aria-valuemax': String(max), 'aria-valuenow': String(v), 'aria-label': p.label || 'Progress' }, h('i', { style: 'width:' + pct + '%' })));
  };
  C.Skeleton = function (p) {
    var shape = pickKey(p.shape, ['line', 'block', 'circle'], 'line');
    var w = p.width, hh = p.height, style = '';
    if (shape === 'circle') { var d = Number(w) || 36; style = 'width:' + px(d) + ';height:' + px(d) + ';border-radius:50%'; }
    else style = 'width:' + (w ? (typeof w === 'number' ? px(w) : w) : '100%') + ';height:' + px(Number(hh) || (shape === 'block' ? 64 : 12));
    return h('span', { class: 'sk live', style: style, role: 'presentation', 'aria-hidden': 'true' });
  };
  C.Spinner = function (p) {
    var sz = { sm: 14, md: 20, lg: 32 }[p.size] || 20;
    return h('span', { class: 'jr-spinner', role: 'status', 'aria-label': 'Loading', style: 'width:' + px(sz) + ';height:' + px(sz) });
  };

  /* ---------- Rafu catalog ---------- */
  JR.mockHost = {
    terminals: { 'term-build': { status: 'live', label: 'swift build' }, 'term-tests': { status: 'needs you', label: 'swift test' }, 'term-docs': { status: 'idle', label: 'docs' } },
    agents: { 'agent-1': { name: 'Claude', state: 'working', last: 'Reading CanvasBoardState.swift', provenance: 'MCP' }, 'agent-2': { name: 'Codex', state: 'idle', last: 'Finished the parity run', provenance: 'Voice' } }
  };
  C.Stat = function (p, k) {
    var intent = pickKey(p.intent, ['good', 'risk', 'neutral'], 'neutral');
    var pending = k.opts.streaming && (p.value === undefined || p.value === null);
    var stat = h('div', { class: 'jr-stat', 'aria-label': str(p.label) + ', ' + str(p.value) + (p.delta ? ', ' + p.delta : '') },
      pending ? h('div', { class: 'v' }, sk('w60', 'h22')) : h('div', { class: 'v' }, str(p.value), p.unit ? h('span', { class: 'u' }, ' ' + str(p.unit)) : null), h('div', { class: 'l' }, str(p.label)),
      p.delta && !pending ? h('div', { class: cx('d', intent !== 'neutral' && intent) }, str(p.delta)) : null);
    return k.kids.length ? h('div', { class: 'ch-spark' }, stat, k.kids) : stat;
  };
  C.KeyValue = function (p) {
    return h('dl', { class: 'jr-kv' }, asList(p.items).map(function (it) { return [h('dt', null, str(it.key)), h('dd', null, str(it.value))]; }));
  };
  C.Timeline = function (p) {
    return h('ol', { class: 'jr-timeline' }, asList(p.events).map(function (ev) {
      var i = pickKey(ev.intent, ['good', 'risk', 'warn', 'info'], null);
      return h('li', { class: i }, h('span', { class: 'jr-time' }, str(ev.time)), h('span', { class: 'dot', 'aria-hidden': 'true' }), h('div', null, h('b', null, str(ev.title)), ev.text ? h('span', { class: 'jr-muted' }, str(ev.text)) : null));
    }));
  };
  function inline(s) {
    var out = [], re = /(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*|\[[^\]]+\]\([^)]+\))/g, last = 0, m;
    while ((m = re.exec(s))) {
      if (m.index > last) out.push(s.slice(last, m.index));
      var t = m[0];
      if (t.indexOf('**') === 0) out.push(h('strong', null, t.slice(2, -2)));
      else if (t.charAt(0) === '`') out.push(h('code', null, t.slice(1, -1)));
      else if (t.charAt(0) === '*') out.push(h('em', null, t.slice(1, -1)));
      else out.push(h('span', { class: 'jr-link', title: t.slice(t.indexOf('](') + 2, -1) }, t.slice(1, t.indexOf(']('))));
      last = m.index + t.length;
    }
    if (last < s.length) out.push(s.slice(last));
    return out;
  }
  C.Markdown = function (p) {
    var lines = str(p.text).split('\n'), out = [], list = null;
    lines.forEach(function (ln) {
      var hd = /^(#{1,3})\s+(.*)$/.exec(ln), li = /^\s*[-*]\s+(.*)$/.exec(ln);
      if (li) { if (!list) { list = []; out.push(h('ul', null, list)); } list.push(h('li', null, inline(li[1]))); return; }
      list = null;
      if (hd) out.push(h('div', { class: 'jr-h jr-h' + (hd[1].length + 1), role: 'heading', 'aria-level': String(hd[1].length + 1) }, inline(hd[2])));
      else if (ln.trim()) out.push(h('p', null, inline(ln)));
    });
    return h('div', { class: 'jr-md' }, out);
  };
  C.Mermaid = function (p) {
    var src = str(p.source), lines = src.split('\n').map(function (s) { return s.trim(); }).filter(Boolean), head = lines[0] || '';
    function nodeTxt(t) {
      var m = /^([A-Za-z0-9_]+)(?:\[([^\]]+)\]|\(([^)]+)\)|\{([^}]+)\})?$/.exec(t.trim());
      return m ? (m[2] || m[3] || m[4] || m[1]) : t.trim();
    }
    if (/^(graph|flowchart)\b/.test(head)) {
      var chains = lines.slice(1).map(function (l) { return l.split(/--+>(?:\|[^|]*\|)?/).map(nodeTxt); });
      return h('div', { class: 'jr-mermaid', role: 'img', 'aria-label': 'Flowchart: ' + chains.map(function (c) { return c.join(' to '); }).join('; ') },
        chains.map(function (c) { return h('div', { class: 'jr-flow' }, c.map(function (t, i) { return [i ? h('span', { class: 'arr', 'aria-hidden': 'true' }, '\u2192') : null, h('span', { class: 'box' }, t)]; })); }));
    }
    if (/^sequenceDiagram/.test(head)) {
      var msgs = lines.slice(1).map(function (l) { return /^(\S+?)-+>>?(\S+?):\s*(.*)$/.exec(l); }).filter(Boolean);
      return h('div', { class: 'jr-mermaid', role: 'img', 'aria-label': 'Sequence diagram with ' + msgs.length + ' messages' },
        msgs.map(function (m) { return h('div', { class: 'jr-flow' }, h('span', { class: 'box' }, m[1]), h('span', { class: 'arr' }, '\u2192'), h('span', { class: 'box' }, m[2]), h('span', { class: 'jr-muted' }, m[3])); }));
    }
    return h('div', { class: 'jr-mermaid fallback' }, h('div', { class: 'jr-muted' }, 'This diagram type is not drawn natively. Showing the source.'), h('pre', null, h('code', null, src)));
  };
  C.Code = function (p) {
    var lines = str(p.text).split('\n'), hl = asList(p.highlightLines).map(Number);
    return h('div', { class: 'jr-code', role: 'region', 'aria-label': 'Code, ' + str(p.language, 'plain text') },
      p.language ? h('div', { class: 'jr-codelang' }, str(p.language)) : null,
      h('pre', null, h('code', null, lines.map(function (ln, i) {
        return h('span', { class: cx('jr-cl', hl.indexOf(i + 1) >= 0 && 'hl') }, h('span', { class: 'ln', 'aria-hidden': 'true' }, String(i + 1)), highlight(ln, p.language), '\n');
      }))));
  };
  var CALLOUT = { note: ['info', 'Note', 'i'], tip: ['good', 'Tip', '\u2713'], risk: ['risk', 'Risk', '!'], decision: ['accent', 'Decision', '\u25c6'] };
  C.Callout = function (p) {
    var c = CALLOUT[p.kind] || CALLOUT.note;
    return h('div', { class: 'jr-alert ' + c[0], role: 'note' }, h('span', { class: 'ic', 'aria-hidden': 'true' }, c[2]),
      h('div', null, h('b', null, c[1] + (p.title ? ': ' + p.title : '')), p.text ? h('span', null, str(p.text)) : null));
  };
  C.Checklist = function (p, k) {
    var m = k.model('items', []), items = asList(m[0]);
    function toggle(i, v) { m[1](items.map(function (it, j) { return j === i ? Object.assign({}, it, { done: v }) : it; })); k.emit('change'); }
    var done = items.filter(function (i) { return i.done; }).length;
    return h('div', { class: 'jr-fieldset' }, items.map(function (it, i) {
      return h('label', { class: cx('jr-choice', it.done && 'done') }, h('input', { type: 'checkbox', p: { checked: !!it.done }, on: { change: function (e) { toggle(i, e.target.checked); } } }), str(it.text));
    }), h('div', { class: 'jr-muted' }, done + ' of ' + items.length + ' done'));
  };
  function chip(label, glyphChar, onClick, title) {
    return h('button', { type: 'button', class: 'jr-chip', title: title || null, on: { click: onClick } }, h('span', { 'aria-hidden': 'true' }, glyphChar), str(label));
  }
  C.FileLink = function (p, k) {
    var base = str(p.path).split('/').pop();
    return chip(p.label || base + (p.line ? ':' + p.line : ''), '\u25a4', function () { k.emit('press'); }, str(p.path) + (p.line ? ':' + p.line : ''));
  };
  C.CardLink = function (p, k) { return chip(p.label || p.node, '\u21aa', function () { k.emit('press'); }, 'Focus Ensemble node ' + str(p.node)); };
  C.TerminalStatus = function (p, k) {
    var t = (k.opts.host || JR.mockHost).terminals[p.node] || { status: 'idle', label: str(p.node) };
    var cls = { live: 'good', 'needs you': 'warn', idle: '' }[t.status];
    return h('div', { class: 'jr-status', on: { click: function () { k.emit('open'); } } }, h('span', { class: cx('jr-dot', cls), 'aria-hidden': 'true' }),
      h('div', null, h('b', null, str(p.title, t.label)), h('span', { class: 'jr-muted' }, str(p.node) + ' \u00b7 ' + t.status)));
  };
  C.AgentStatus = function (p) {
    var a = (JR.mockHost).agents[p.node] || { name: str(p.agent, 'Agent'), state: 'idle', last: '', provenance: 'Unknown' };
    return h('div', { class: 'jr-status' }, h('span', { class: cx('jr-dot', a.state === 'working' ? 'good' : ''), 'aria-hidden': 'true' }),
      h('div', null, h('b', null, str(p.agent, a.name), ' \u00b7 ', a.state), h('span', { class: 'jr-muted' }, a.last)), h('span', { class: 'jr-badge' }, 'via ' + a.provenance));
  };
  C.DiffSummary = function (p, k) {
    var files = asList(p.files), add = files.reduce(function (s, f) { return s + (Number(f.added) || 0); }, 0), rem = files.reduce(function (s, f) { return s + (Number(f.removed) || 0); }, 0);
    return h('div', { class: 'jr-diff' }, h('div', { class: 'jr-row' }, h('b', null, files.length + (files.length === 1 ? ' file' : ' files') + ' changed'), h('span', { class: 'jr-pos' }, '+' + add), h('span', { class: 'jr-neg' }, '\u2212' + rem)),
      files.map(function (f) {
        return h('div', { class: 'jr-row between' }, chip(f.path.split('/').pop(), '\u25a4', function () { k.store.note({ action: 'open_file', params: { path: f.path }, host: true }); k.store.notify(); }, f.path),
          h('span', { class: 'jr-row' }, h('span', { class: 'jr-pos' }, '+' + (f.added || 0)), h('span', { class: 'jr-neg' }, '\u2212' + (f.removed || 0))));
      }));
  };
  C.IconLibraryIcon = function (p) {
    var sz = Number(p.size) || 24;
    return h('span', { class: 'jr-iconlib', role: 'img', 'aria-label': str(p.pack) + ' icon ' + str(p.icon), title: str(p.pack) + ' / ' + str(p.icon), style: 'width:' + px(sz) + ';height:' + px(sz) + ';font-size:' + Math.round(sz * 0.5) + 'px' }, str(p.icon).charAt(0).toUpperCase());
  };

  JR.render = render;
  JR.highlight = highlight;
  JR.skeletonFor = skeletonFor;
  JR.register = function (name, fn) { C[name] = fn; };
})(typeof globalThis !== 'undefined' ? globalThis : this);
