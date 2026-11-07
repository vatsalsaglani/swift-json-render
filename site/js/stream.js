/* Streaming demo: replays JSONL patches into the renderer with step, speed and a scrubber. */
(function (g) {
  'use strict';
  var JR = g.JR, ui = JR.ui, E = JR.engine, doc = g.document, el = ui.el;
  var $ = function (id) { return doc.getElementById(id); };

  var sc = null, items = [], n = 0, playing = false, timer = null, speed = 1, finalStore = null, finalFor = -1;

  function parse(lines) {
    return lines.map(function (raw, i) {
      var t = raw.trim();
      try { return { i: i, raw: raw, patch: JSON.parse(t) }; } catch (e) { return { i: i, raw: raw, bad: true }; }
    });
  }

  /* Replay the first k lines. Returns the spec, the journal and the domains the chart saw (monotonic across the replay). */
  function replay(k, mountOut) {
    var spec = { elements: {} }, journal = [], domains = {}, store = null;
    for (var i = 0; i <= k; i++) {
      if (i > 0) {
        var it = items[i - 1];
        if (it.bad) journal.push('line ' + i + ': not valid JSON, skipped');
        else { try { spec = E.applyPatch(spec, it.patch); } catch (err) { journal.push('line ' + i + ': ' + err.message); } }
      }
      var done = k === items.length && i === k;
      var opts = { streaming: !done, domains: domains, domainNote: function (id) { return 'y-domain 0 to ' + (domains[id] || 0) + '. It only grows while the stream runs.'; } };
      if (i === k) {
        if (done) {
          if (finalFor !== k || !finalStore) { finalStore = E.createStore(spec.state); finalFor = k; finalStore.subscribe(redrawFinal); }
          store = finalStore;
        } else { store = E.createStore(spec.state); finalStore = null; finalFor = -1; }
        return { spec: spec, journal: journal, store: store, opts: opts };
      }
      var tmp = E.createStore(spec.state);
      JR.render(spec, tmp, opts); /* advances the monotonic domains; output is discarded */
    }
  }

  var last = null;
  function redrawFinal() { if (last && n > 0) JR.mount($('out'), JR.render(last.spec, last.store, last.opts)); }

  function draw() {
    var r = last = replay(n);
    if (n === 0) JR.mount($('out'), JR.h('div', { class: 'jr-note' }, 'Waiting for the first patch.'));
    else JR.mount($('out'), JR.render(r.spec, r.store, r.opts));
    $('pos').textContent = n + ' / ' + items.length;
    $('scrub').value = String(n);
    [].forEach.call($('lines').children, function (li, i) {
      var applied = i < n;
      li.className = (applied ? 'done ' : '') + (i === n - 1 ? 'cur ' : '') + (items[i].bad ? 'bad' : '');
      if (i === n - 1) li.setAttribute('aria-current', 'step'); else li.removeAttribute('aria-current');
      li.firstChild.nextSibling.textContent = !applied ? '' : items[i].bad ? '!' : '✓';
    });
    var cur = $('lines').children[n - 1];
    if (cur && cur.scrollIntoView && !g.matchMedia('(prefers-reduced-motion: reduce)').matches) cur.scrollIntoView({ block: 'nearest' });
    var spec = r.spec, ids = Object.keys(spec.elements || {}), dang = E.danglingIds(spec), complete = n === items.length;
    var info = $('info');
    info.textContent = '';
    [['Patches applied', String(n - r.journal.length)], ['Elements', String(ids.length)], ['Dangling ids', dang.length ? dang.join(', ') : 'none'], ['Streaming', complete ? 'no (frozen)' : 'yes']].forEach(function (p) {
      info.appendChild(el('div', null, [el('b', { text: p[0] }), p[1]]));
    });
    $('journal').textContent = r.journal.length ? 'Journal: ' + r.journal.join('; ') : '';
    var msg;
    if (n === 0) msg = 'Nothing has arrived yet. Press Play or Step.';
    else if (complete) msg = 'End of stream. The spec is validated, dangling ids are pruned, and the view is frozen. ' + (sc.domain ? 'The chart has settled to its final domain.' : 'Interact with the card.');
    else if (!spec.root) msg = 'No root yet.';
    else msg = dang.length ? 'Waiting for ' + dang.length + ' element' + (dang.length > 1 ? 's' : '') + ': skeletons hold their place.' : 'All referenced elements are here.';
    $('status').textContent = msg;
    $('play').textContent = playing ? 'Pause' : n >= items.length ? 'Replay' : 'Play';
    $('back').disabled = n === 0;
    $('fwd').disabled = n >= items.length;
  }

  function summary(it) {
    if (it.bad) return [el('span', { class: 'op', text: 'bad' }), ' ' + it.raw];
    var p = it.patch;
    return [el('span', { class: 'op', text: p.op }), ' ' + p.path];
  }

  function load(s) {
    stop();
    sc = s; items = parse(s.lines); n = 0; finalStore = null; finalFor = -1;
    $('blurb').textContent = s.blurb;
    $('scrub').max = String(items.length);
    var ol = $('lines');
    ol.textContent = '';
    items.forEach(function (it, i) {
      var li = el('li', { title: it.raw }, [el('span', { class: 'n', text: String(i + 1) }), el('span', { 'aria-hidden': 'true' }), el('span', { class: 't' }, summary(it))]);
      ol.appendChild(li);
    });
    [].forEach.call($('scen').children, function (b) { b.setAttribute('aria-pressed', b.getAttribute('data-id') === s.id ? 'true' : 'false'); });
    draw();
  }

  function stop() { playing = false; if (timer) { g.clearTimeout(timer); timer = null; } }
  function tick() {
    if (!playing) return;
    if (n >= items.length) { stop(); draw(); return; }
    n++; draw();
    if (n >= items.length) { stop(); draw(); return; }
    timer = g.setTimeout(tick, 900 / speed);
  }
  function toggle() {
    if (playing) { stop(); draw(); return; }
    if (n >= items.length) n = 0;
    playing = true; draw(); timer = g.setTimeout(tick, 400 / speed);
  }

  ui.ready(function () {
    ui.initTheme(); ui.initKeys();
    var scen = $('scen');
    JR.streams.forEach(function (s) {
      var b = el('button', { type: 'button', 'aria-pressed': 'false', 'data-id': s.id, text: s.title });
      b.addEventListener('click', function () { load(s); });
      scen.appendChild(b);
    });
    $('play').addEventListener('click', toggle);
    $('fwd').addEventListener('click', function () { stop(); if (n < items.length) n++; draw(); });
    $('back').addEventListener('click', function () { stop(); if (n > 0) n--; draw(); });
    $('restart').addEventListener('click', function () { stop(); n = 0; draw(); });
    $('speed').addEventListener('change', function (e) { speed = Number(e.target.value) || 1; });
    $('scrub').addEventListener('input', function (e) { stop(); n = Number(e.target.value); draw(); });
    /* ?s=chart&n=6 opens a stream at a given line, so a moment can be shared. */
    var qs = g.location.search, sm = /[?&]s=([a-z]+)/.exec(qs), nm = /[?&]n=(\d+)/.exec(qs);
    var first = (sm && JR.streams.filter(function (x) { return x.id === sm[1]; })[0]) || JR.streams[0];
    load(first);
    if (nm) { n = Math.min(items.length, Number(nm[1])); draw(); }
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
