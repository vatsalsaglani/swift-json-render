/* JSONRenderCharts mocks: 15 chart components drawn with HTML, CSS and SVG in the plan's mock style.
   Charts read state, never fetch. During a stream the y-domain only grows (k.domain). */
(function (g) {
  'use strict';
  var JR = (g.JR = g.JR || {});
  var h = JR.h, E = JR.engine, C = JR.components;

  function cx() { return Array.prototype.filter.call(arguments, Boolean).join(' '); }
  function asList(v) { return Array.isArray(v) ? v : []; }
  function num(v) { var n = Number(v); return isFinite(n) ? n : 0; }
  function round(n, d) { var f = Math.pow(10, d || 0); return Math.round(n * f) / f; }
  function pct(v, max) { return max > 0 ? Math.max(0, Math.min(100, (v / max) * 100)) : 0; }
  function pickKey(v, allowed, def) { return allowed.indexOf(v) >= 0 ? v : def; }

  function niceCeil(x) {
    if (!(x > 0)) return 1;
    var e = Math.pow(10, Math.floor(Math.log10(x))), f = x / e;
    var steps = [1, 1.2, 1.5, 2, 2.5, 3, 4, 5, 6, 8, 10];
    for (var i = 0; i < steps.length; i++) if (f <= steps[i] + 1e-9) return steps[i] * e;
    return 10 * e;
  }

  function fmt(v, format, unit) {
    if (v === undefined || v === null || isNaN(Number(v))) return '';
    var n = Number(v), s, kind = String(format || 'number').split(':')[0], abs = Math.abs(n);
    if (kind === 'compact') s = abs >= 1e6 ? round(n / 1e6, 1) + 'M' : abs >= 1e3 ? round(n / 1e3, 1) + 'k' : String(round(n, 1));
    else if (kind === 'percent') s = round(n, 1) + ' %';
    else if (kind === 'currency') s = '$' + n.toFixed(2);
    else if (kind === 'duration') s = abs >= 60 ? Math.floor(n / 60) + 'm ' + Math.round(n % 60) + 's' : round(n, 1) + ' s';
    else if (kind === 'bytes') s = abs >= 1048576 ? round(n / 1048576, 1) + ' MB' : abs >= 1024 ? round(n / 1024, 1) + ' KB' : round(n) + ' B';
    else s = round(n, 2).toLocaleString('en-US');
    return unit && kind !== 'currency' && kind !== 'percent' ? s + ' ' + unit : s;
  }

  function hpx(p, k) {
    if (k.opts.dense) return 96;
    return { compact: 96, regular: 140, tall: 220 }[p.height] || 140;
  }
  function sCls(i) { return 's' + ((i % 5) + 1); }
  var INTENT = { good: 'var(--m-good)', warn: 'var(--m-warn)', warning: 'var(--m-warn)', risk: 'var(--m-risk)', critical: 'var(--m-risk)', info: 'var(--m-accent)' };

  function dropLegend(parts) {
    return Array.isArray(parts) ? parts.filter(function (x) { return !(x && x.a && x.a.class === 'ch-leg'); }).map(dropLegend) : parts;
  }
  function shell(p, k, name, summary, parts) {
    if (p.legend === 'hidden') parts = dropLegend(parts);
    return h('div', { class: 'ch', role: 'group', 'aria-label': p.summary || summary }, parts, k.opts.streaming && k.opts.domainNote ? h('div', { class: 'jr-muted ch-note' }, k.opts.domainNote(k.id)) : null);
  }

  function selection(k) {
    var m = k.model('selection', null);
    return {
      bound: m[2], value: m[0],
      attrs: function (val, label) {
        if (!m[2]) return {};
        return { role: 'button', tabindex: '0', 'aria-pressed': m[0] === val ? 'true' : 'false', 'aria-label': label,
          on: { click: function () { m[1](m[0] === val ? null : val); }, keydown: function (e) { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); m[1](m[0] === val ? null : val); } } } };
      },
      on: function (val) { return m[2] && m[0] === val; },
      dim: function (val) { return m[2] && m[0] !== null && m[0] !== undefined && m[0] !== val; }
    };
  }

  function legend(names, dir) {
    return h('div', { class: 'ch-leg' }, names.map(function (n, i) { return h('span', null, h('i', { class: sCls(i) }), n); }));
  }

  /* y grid with 3 ticks, plot area for content */
  function plot(max, height, content, format, unit, refs) {
    var ticks = [0, 0.5, 1];
    return h('div', { class: 'ch-plot', style: 'height:' + height + 'px' },
      h('div', { class: 'ch-ygrid', 'aria-hidden': 'true' }, ticks.map(function (t) { return h('span', { style: 'bottom:' + t * 100 + '%' }, h('em', null, fmt(max * t, format === 'duration' ? 'number' : format))); })),
      h('div', { class: 'ch-area' }, content, asList(refs).map(function (r) {
        return h('div', { class: 'ch-ref', style: 'bottom:' + pct(num(r.value), max) + '%;border-color:' + (INTENT[r.intent] || 'var(--m-muted)') }, r.label ? h('span', { style: 'color:' + (INTENT[r.intent] || 'var(--m-muted)') }, r.label) : null);
      })));
  }
  function xLabels(cats, mode) {
    var show = cats;
    if (mode === 'edge' && cats.length > 8) { show = [0, 0.25, 0.5, 0.75, 1].map(function (f) { return cats[Math.round(f * (cats.length - 1))]; }); }
    return h('div', { class: mode === 'edge' ? 'ch-x edge' : 'ch-x' }, show.map(function (c) { return h('span', null, c); }));
  }

  /* group rows into categories x series */
  function pivot(rows, xk, yk, sk) {
    var cats = [], series = [], mat = {};
    rows.forEach(function (r) {
      var c = String(r[xk]), s = sk ? String(r[sk]) : '_';
      if (cats.indexOf(c) < 0) cats.push(c);
      if (series.indexOf(s) < 0) series.push(s);
      mat[c] = mat[c] || {};
      mat[c][s] = (mat[c][s] || 0) + num(r[yk]);
    });
    return { cats: cats, series: series, mat: mat };
  }
  function total(pv, c) { return pv.series.reduce(function (s, n) { return s + (pv.mat[c][n] || 0); }, 0); }

  /* ---------- BarChart ---------- */
  C.BarChart = function (p, k) {
    var rows = asList(p.data), xk = p.x || 'x', yk = p.y || 'y', pv = pivot(rows, xk, yk, p.series);
    var layout = pickKey(p.layout, ['grouped', 'stacked', 'normalized'], 'grouped'), horiz = p.orientation === 'horizontal';
    var cats = pv.cats.slice(), other = null;
    if (p.sort === 'asc' || p.sort === 'desc') cats.sort(function (a, b) { return p.sort === 'asc' ? total(pv, a) - total(pv, b) : total(pv, b) - total(pv, a); });
    if (p.limit && cats.length > p.limit) {
      var rest = cats.slice(p.limit);
      cats = cats.slice(0, p.limit);
      other = {}; pv.series.forEach(function (s) { other[s] = rest.reduce(function (t, c) { return t + (pv.mat[c][s] || 0); }, 0); });
      pv.mat['Other (' + rest.length + ')'] = other; cats.push('Other (' + rest.length + ')');
    }
    var multi = !!p.series && pv.series.length > 1;
    var rawMax = Math.max.apply(null, cats.map(function (c) {
      return layout === 'grouped' ? Math.max.apply(null, pv.series.map(function (s) { return pv.mat[c][s] || 0; })) : total(pv, c);
    }).concat([0]));
    var max = layout === 'normalized' ? 100 : p.yDomain ? num(p.yDomain[1]) : k.domain(niceCeil(rawMax));
    var sel = selection(k);
    function size(c, s) {
      var v = pv.mat[c][s] || 0;
      return layout === 'normalized' ? pct(v, total(pv, c) || 1) * 1 : pct(v, max);
    }
    var body;
    if (horiz) {
      body = h('div', { class: 'ch-hbars' }, cats.map(function (c, ci) {
        var isOther = c.indexOf('Other (') === 0, tot = total(pv, c);
        var track;
        if (layout === 'stacked' || layout === 'normalized') {
          track = h('span', { class: 'bar stacked' }, pv.series.map(function (s, si) { return h('i', { class: isOther ? 's5' : sCls(si), style: 'width:' + (layout === 'normalized' ? pct(pv.mat[c][s] || 0, tot || 1) : pct(pv.mat[c][s] || 0, max)) + '%' }); }));
        } else if (multi) {
          track = h('span', { class: 'bar multi' }, pv.series.map(function (s, si) { return h('i', { class: sCls(si), style: 'width:' + pct(pv.mat[c][s] || 0, max) + '%' }); }));
        } else track = h('span', { class: 'bar' }, h('i', { class: isOther ? 's5' : null, style: 'width:' + pct(tot, max) + '%' }));
        return h('div', Object.assign({ class: cx('hbar', sel.on(c) && 'sel', sel.dim(c) && 'dim') }, sel.attrs(c, c + ', ' + fmt(tot, p.format, p.unit))),
          h('span', { class: 'lbl' }, c), track, h('span', { class: 'v' }, layout === 'normalized' ? '100 %' : fmt(tot, p.format)));
      }));
    } else {
      body = plot(max, hpx(p, k), h('div', { class: 'ch-bars' }, cats.map(function (c) {
        var isOther = c.indexOf('Other (') === 0;
        var inner;
        if (layout === 'grouped') inner = pv.series.map(function (s, si) { return h('i', { class: isOther ? 's5' : sCls(si), title: c + ' ' + (multi ? s + ' ' : '') + fmt(pv.mat[c][s] || 0, p.format, p.unit), style: 'height:' + size(c, s) + '%' }); });
        else inner = pv.series.map(function (s, si) { return h('i', { class: sCls(si), title: c + ' ' + s + ' ' + fmt(pv.mat[c][s] || 0, p.format, p.unit), style: 'height:' + size(c, s) + '%' }); });
        return h('div', Object.assign({ class: cx('ch-col', layout === 'grouped' && 'grp', sel.on(c) && 'sel', sel.dim(c) && 'dim') }, sel.attrs(c, c + ', ' + fmt(total(pv, c), p.format, p.unit))), inner);
      })), layout === 'normalized' ? 'percent' : p.format, p.unit, p.referenceLines);
      body = [body, xLabels(cats, 'cols')];
    }
    return shell(p, k, 'Bar chart', 'Bar chart, ' + cats.length + ' categories, highest ' + fmt(rawMax, p.format, p.unit), [body, multi ? legend(pv.series) : null, p.unit && !horiz ? h('div', { class: 'jr-muted ch-note' }, 'Unit: ' + p.unit) : null]);
  };

  /* ---------- paths ---------- */
  function pathFor(pts, curve, close, H) {
    if (!pts.length) return '';
    var d = 'M' + pts[0][0] + ',' + pts[0][1];
    for (var i = 1; i < pts.length; i++) {
      var a = pts[i - 1], b = pts[i];
      if (curve === 'step') d += ' L' + b[0] + ',' + a[1] + ' L' + b[0] + ',' + b[1];
      else if (curve === 'monotone') { var mx = (a[0] + b[0]) / 2; d += ' C' + mx + ',' + a[1] + ' ' + mx + ',' + b[1] + ' ' + b[0] + ',' + b[1]; }
      else d += ' L' + b[0] + ',' + b[1];
    }
    if (close) d += ' L' + pts[pts.length - 1][0] + ',' + H + ' L' + pts[0][0] + ',' + H + ' Z';
    return d;
  }
  var SVGBASE = { viewBox: '0 0 100 100', preserveAspectRatio: 'none', 'aria-hidden': 'true' };
  function xAt(i, n) { return n > 1 ? (i / (n - 1)) * 100 : 50; }

  C.LineChart = function (p, k) {
    var rows = asList(p.data), pv = pivot(rows, p.x || 'x', p.y || 'y', p.series), cats = pv.cats;
    var max = p.yDomain ? num(p.yDomain[1]) : k.domain(niceCeil(Math.max.apply(null, rows.map(function (r) { return num(r[p.y || 'y']); }).concat(asList(p.referenceLines).map(function (r) { return num(r.value); }), [0]))));
    var points = p.points || 'auto', showDots = points === 'always' || (points === 'auto' && cats.length <= 12);
    var lines = pv.series.map(function (s, si) {
      var pts = cats.map(function (c, i) { return [xAt(i, cats.length), 100 - pct(pv.mat[c][s] || 0, max)]; });
      return { pts: pts, d: pathFor(pts, p.curve, false, 100), cls: sCls(si) };
    });
    var content = [h('svg', SVGBASE, lines.map(function (l) { return h('path', { d: l.d, class: 'ln ' + l.cls, fill: 'none', 'vector-effect': 'non-scaling-stroke' }); })),
      showDots ? h('div', { class: 'ch-dots' }, lines.map(function (l) { return l.pts.map(function (pt) { return h('i', { class: l.cls, style: 'left:' + pt[0] + '%;top:' + pt[1] + '%' }); }); })) : null];
    return shell(p, k, 'Line chart', 'Line chart, ' + cats.length + ' points, ' + pv.series.length + ' series', [plot(max, hpx(p, k), content, p.format, p.unit, p.referenceLines), xLabels(cats, 'edge'), p.series ? legend(pv.series) : null]);
  };

  C.AreaChart = function (p, k) {
    var rows = asList(p.data), pv = pivot(rows, p.x || 'x', p.y || 'y', p.series), cats = pv.cats, layout = pickKey(p.layout, ['overlap', 'stacked', 'normalized'], 'overlap');
    var totals = cats.map(function (c) { return total(pv, c); });
    var raw = layout === 'overlap' ? Math.max.apply(null, rows.map(function (r) { return num(r[p.y || 'y']); }).concat([0])) : Math.max.apply(null, totals.concat([0]));
    var max = layout === 'normalized' ? 100 : p.yDomain ? num(p.yDomain[1]) : k.domain(niceCeil(raw));
    var base = cats.map(function () { return 0; }), shapes = [];
    pv.series.forEach(function (s, si) {
      var top = cats.map(function (c, i) {
        var v = pv.mat[c][s] || 0;
        if (layout === 'normalized') v = (v / (totals[i] || 1)) * 100;
        return layout === 'overlap' ? v : base[i] + v;
      });
      var up = top.map(function (v, i) { return [xAt(i, cats.length), 100 - pct(v, max)]; });
      var lo = (layout === 'overlap' ? top.map(function () { return 0; }) : base).map(function (v, i) { return [xAt(i, cats.length), 100 - pct(v, max)]; });
      var d = pathFor(up, 'linear', false, 100) + ' ' + lo.slice().reverse().map(function (pt) { return 'L' + pt[0] + ',' + pt[1]; }).join(' ') + ' Z';
      shapes.push(h('path', { d: d, class: 'ar ' + sCls(si) + (layout === 'overlap' ? ' ov' : ''), 'vector-effect': 'non-scaling-stroke' }));
      if (layout !== 'overlap') base = top;
    });
    return shell(p, k, 'Area chart', 'Area chart, ' + layout + ', ' + cats.length + ' points', [plot(max, hpx(p, k), h('svg', SVGBASE, shapes), layout === 'normalized' ? 'percent' : p.format, p.unit, p.referenceLines), xLabels(cats, 'edge'), p.series ? legend(pv.series) : null]);
  };

  /* ---------- PieChart ---------- */
  C.PieChart = function (p, k) {
    var rows = asList(p.data).map(function (r) { return { label: String(r[p.label || 'label']), value: Math.max(0, num(r[p.value || 'value'])) }; });
    rows.sort(function (a, b) { return b.value - a.value; });
    var maxSlices = p.maxSlices || 6;
    if (rows.length > maxSlices) {
      var rest = rows.slice(maxSlices - 1);
      rows = rows.slice(0, maxSlices - 1).concat([{ label: 'Other', value: rest.reduce(function (s, r) { return s + r.value; }, 0), other: true }]);
    }
    var tot = rows.reduce(function (s, r) { return s + r.value; }, 0) || 1, acc = 0, stops = [];
    rows.forEach(function (r, i) {
      var from = acc, to = acc + (r.value / tot) * 100, col = r.other ? 'var(--c5)' : 'var(--c' + ((i % 5) + 1) + ')';
      stops.push(col + ' ' + from + '% ' + Math.max(from, to - 0.6) + '%', 'var(--m-card) ' + Math.max(from, to - 0.6) + '% ' + to + '%');
      acc = to;
    });
    var center = p.center, ctr = null;
    if (p.donut && center) ctr = typeof center === 'object' ? [h('b', null, String(center.value)), h('span', null, String(center.label || ''))] : [h('b', null, String(center))];
    var sel = selection(k);
    return shell(p, k, 'Pie chart', (p.donut ? 'Donut' : 'Pie') + ' chart, ' + rows.length + ' slices, largest ' + (rows[0] ? rows[0].label : ''), h('div', { class: 'ch-pie-row' },
      h('div', { class: cx('ch-donut', !p.donut && 'pie'), style: 'background:conic-gradient(' + (stops.join(',') || 'var(--m-line) 0 100%') + ')' }, ctr ? h('div', { class: 'ctr' }, ctr) : null),
      h('div', { class: 'ch-dl' }, rows.map(function (r, i) {
        return h('div', Object.assign({ class: cx('ch-dlrow', sel.on(r.label) && 'sel', sel.dim(r.label) && 'dim') }, sel.attrs(r.label, r.label + ', ' + fmt(r.value, p.format))),
          h('i', { class: r.other ? 's5' : sCls(i) }), h('span', null, r.label), h('span', { class: 'n' }, fmt(r.value, p.format) + ' (' + Math.round((r.value / tot) * 100) + ' %)'));
      }))));
  };

  /* ---------- Gauge ---------- */
  C.Gauge = function (p, k) {
    var min = num(p.min), max = p.max === undefined ? 100 : num(p.max), v = num(p.value), f = max > min ? Math.max(0, Math.min(1, (v - min) / (max - min))) : 0;
    var style = pickKey(p.style, ['arc', 'ring', 'linear'], 'arc'), bands = asList(p.bands);
    var band = bands.filter(function (b) { return v <= num(b.to); })[0] || bands[bands.length - 1];
    var col = band ? INTENT[band.intent] || 'var(--m-accent)' : 'var(--m-accent)';
    var vtxt = p.format ? fmt(v, p.format, p.unit) : (p.unit && p.unit === '%' ? round(v, 1) + ' %' : fmt(v, 'number', p.unit)), sub = p.label ? p.label : '';
    var a11y = (p.label || 'Gauge') + ': ' + vtxt + ' of ' + fmt(max, p.format, p.unit);
    var body;
    if (style === 'ring') body = h('div', { class: 'ch-gauges' }, h('div', null, h('div', { class: 'ch-ring', style: 'background:conic-gradient(' + col + ' 0 ' + f * 100 + '%,var(--m-line) 0)' }, h('span', { class: 'val' }, vtxt)), h('div', { class: 'ch-gl' }, sub)));
    else if (style === 'linear') {
      var track = bands.length ? bands.map(function (b, i) { var prev = i ? num(bands[i - 1].to) : min; return h('span', { style: 'width:' + pct(num(b.to) - prev, max - min) + '%;background:' + (INTENT[b.intent] || 'var(--m-accent)') }); }) : [h('span', { style: 'width:100%;background:var(--m-muted)' })];
      body = h('div', null, h('div', { class: 'ch-lin' }, h('div', { class: 'track' }, track), h('div', { class: 'fill', style: 'width:' + f * 100 + '%' }), p.target !== undefined ? h('div', { class: 'mk', style: 'left:' + pct(num(p.target) - min, max - min) + '%' }) : null),
        h('div', { class: 'ch-lin-lbl' }, h('span', null, (sub ? sub + ' ' : '') + vtxt), p.target !== undefined ? h('span', null, 'target ' + fmt(p.target, p.format, p.unit)) : h('span', null, fmt(max, p.format, p.unit))));
    } else body = h('div', { class: 'ch-gauges' }, h('div', null, h('div', { class: 'ch-arc', style: '--p:' + f * 100 + ';--gc:' + col }, h('span', { class: 'val' }, vtxt)), h('div', { class: 'ch-gl' }, (sub ? sub + ' · ' : '') + Math.round(f * 100) + ' %' + (p.target !== undefined ? ' · target ' + fmt(p.target, p.format, p.unit) : ''))));
    return h('div', { class: 'ch', role: 'meter', 'aria-valuemin': String(min), 'aria-valuemax': String(max), 'aria-valuenow': String(v), 'aria-label': a11y }, body);
  };

  /* ---------- Sparkline ---------- */
  C.Sparkline = function (p) {
    var vals = asList(p.values).map(num), W = 96, H = 28, lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals), span = hi - lo || 1;
    var pts = vals.map(function (v, i) { return [round(xAt(i, vals.length) * W / 100, 1), round(H - 3 - ((v - lo) / span) * (H - 6), 1)]; });
    var col = INTENT[p.intent] || 'var(--m-accent)';
    var emph = pickKey(p.emphasis, ['last', 'max', 'none'], 'last'), ep = emph === 'last' ? pts[pts.length - 1] : emph === 'max' ? pts[vals.indexOf(hi)] : null;
    return h('svg', { class: 'ch-sparksvg', viewBox: '0 0 ' + W + ' ' + H, role: 'img', 'aria-label': 'Sparkline, ' + vals.length + ' values, last ' + (vals[vals.length - 1]) },
      p.filled ? h('path', { d: pathFor(pts, 'linear', true, H), style: 'fill:' + col + ';opacity:.18' }) : null,
      h('path', { d: pathFor(pts, 'linear', false, H), style: 'fill:none;stroke:' + col + ';stroke-width:1.5' }), ep ? h('circle', { cx: String(ep[0]), cy: String(ep[1]), r: '2.5', style: 'fill:' + col }) : null);
  };

  /* ---------- ScatterChart ---------- */
  C.ScatterChart = function (p, k) {
    var rows = asList(p.data), xk = p.x || 'x', yk = p.y || 'y', xs = rows.map(function (r) { return num(r[xk]); }), ys = rows.map(function (r) { return num(r[yk]); });
    var xmin = Math.min.apply(null, xs), xmax = Math.max.apply(null, xs), ymax = k.domain(niceCeil(Math.max.apply(null, ys.concat([0]))));
    var xspan = xmax - xmin || 1, smax = p.size ? Math.max.apply(null, rows.map(function (r) { return num(r[p.size]); }).concat([1])) : 0, names = [];
    var dots = rows.map(function (r, i) {
      var si = 0;
      if (p.series) { var s = String(r[p.series]); if (names.indexOf(s) < 0) names.push(s); si = names.indexOf(s); }
      var d = p.size ? 6 + (num(r[p.size]) / smax) * 14 : 7;
      return h('i', { class: sCls(si) + (p.size ? ' bub' : ''), title: xk + ' ' + xs[i] + ', ' + yk + ' ' + ys[i], style: 'left:' + ((xs[i] - xmin) / xspan) * 100 + '%;top:' + (100 - pct(ys[i], ymax)) + '%;width:' + round(d, 1) + 'px;height:' + round(d, 1) + 'px' });
    });
    var trend = null;
    if (p.trend === 'linear' && rows.length > 1) {
      var mx = xs.reduce(function (a, b) { return a + b; }, 0) / xs.length, my = ys.reduce(function (a, b) { return a + b; }, 0) / ys.length, sxy = 0, sxx = 0;
      xs.forEach(function (x, i) { sxy += (x - mx) * (ys[i] - my); sxx += (x - mx) * (x - mx); });
      var m = sxx ? sxy / sxx : 0, b = my - m * mx, y0 = m * xmin + b, y1 = m * xmax + b;
      trend = h('svg', SVGBASE, h('line', { x1: '0', y1: String(100 - pct(y0, ymax)), x2: '100', y2: String(100 - pct(y1, ymax)), class: 'trend', 'vector-effect': 'non-scaling-stroke' }));
    }
    return shell(p, k, 'Scatter chart', 'Scatter chart, ' + rows.length + ' points' + (p.trend === 'linear' ? ', with linear fit' : ''), [plot(ymax, hpx(p, k), [trend, h('div', { class: 'ch-dots free' }, dots)], p.format, p.unit, p.referenceLines),
      h('div', { class: 'ch-lin-lbl pad' }, h('span', null, xk + ' ' + fmt(xmin)), h('span', null, fmt(xmax))), names.length > 1 ? legend(names) : null]);
  };

  /* ---------- Heatmap ---------- */
  C.Heatmap = function (p, k) {
    var rows = asList(p.data), xk = p.x || 'x', yk = p.y || 'y', vk = p.value || 'value', xs = [], ys = [], cell = {}, vmin = Infinity, vmax = -Infinity;
    rows.forEach(function (r) {
      var x = String(r[xk]), y = String(r[yk]);
      if (xs.indexOf(x) < 0) xs.push(x);
      if (ys.indexOf(y) < 0) ys.push(y);
      cell[x + '|' + y] = num(r[vk]); vmin = Math.min(vmin, num(r[vk])); vmax = Math.max(vmax, num(r[vk]));
    });
    var span = vmax - vmin || 1, mid = (vmax + vmin) / 2, div = p.scale === 'diverging', cal = p.layout === 'calendar';
    var grid = [];
    ys.forEach(function (y) {
      xs.forEach(function (x) {
        var v = cell[x + '|' + y], hasV = v !== undefined, op, bg = 'var(--m-accent)';
        if (div) { op = hasV ? 0.15 + 0.8 * (Math.abs(v - mid) / (span / 2)) : 0.06; bg = v < mid ? 'var(--m-warn)' : 'var(--m-accent)'; }
        else op = hasV ? 0.1 + 0.85 * ((v - vmin) / span) : 0.06;
        grid.push(h('i', { title: x + ', ' + y + ': ' + (hasV ? fmt(v) : 'no data'), style: 'opacity:' + round(op, 2) + ';background:' + bg }));
      });
    });
    return shell(p, k, 'Heatmap', 'Heatmap, ' + xs.length + ' by ' + ys.length + ' cells, range ' + fmt(vmin) + ' to ' + fmt(vmax), [
      h('div', { class: 'ch-heatwrap' }, h('div', { class: 'ch-heatlab' }, ys.map(function (y) { return h('span', null, y); })),
        h('div', { class: cx('ch-heat', cal && 'cal'), style: 'grid-template-columns:repeat(' + xs.length + ',minmax(0,1fr))' }, grid)),
      h('div', { class: 'ch-lin-lbl pad' }, h('span', null, xs[0]), h('span', null, xs[xs.length - 1])),
      h('div', { class: 'jr-muted ch-note' }, div ? 'Diverging scale around ' + fmt(mid) + '.' : 'One hue, darker means more.')]);
  };

  /* ---------- Histogram ---------- */
  C.Histogram = function (p, k) {
    var vals = asList(p.values).map(num), n = vals.length;
    var bins = p.bins === undefined || p.bins === 'auto' ? Math.max(3, Math.ceil(Math.log2(Math.max(2, n)) + 1)) : Math.max(1, Math.floor(num(p.bins)));
    var lo = Math.min.apply(null, vals), hi = Math.max.apply(null, vals), w = (hi - lo) / bins || 1, counts = [];
    for (var i = 0; i < bins; i++) counts.push(0);
    vals.forEach(function (v) { counts[Math.min(bins - 1, Math.floor((v - lo) / w))]++; });
    var percent = p.show === 'percent', ys = counts.map(function (c) { return percent ? (c / (n || 1)) * 100 : c; }), max = k.domain(niceCeil(Math.max.apply(null, ys.concat([0]))));
    return shell(p, k, 'Histogram', 'Histogram, ' + n + ' values in ' + bins + ' bins', [plot(max, hpx(p, k), h('div', { class: 'ch-bars tight' }, ys.map(function (v, i) {
      return h('div', { class: 'ch-col' }, h('i', { title: fmt(lo + i * w, 'number', p.unit) + ' to ' + fmt(lo + (i + 1) * w, 'number', p.unit) + ': ' + (percent ? round(v, 1) + ' %' : counts[i]), style: 'height:' + pct(v, max) + '%' }));
    })), percent ? 'percent' : 'number'), h('div', { class: 'ch-lin-lbl pad' }, h('span', null, fmt(lo, 'number', p.unit)), h('span', null, fmt(hi, 'number', p.unit)))]);
  };

  /* ---------- ComboChart ---------- */
  C.ComboChart = function (p, k) {
    var rows = asList(p.data), xk = p.x || 'x', bk = p.bars || 'bars', lk = p.line || 'line', cats = rows.map(function (r) { return String(r[xk]); });
    var max = k.domain(niceCeil(Math.max.apply(null, rows.map(function (r) { return Math.max(num(r[bk]), num(r[lk])); }).concat([0]))));
    var pts = rows.map(function (r, i) { return [((i + 0.5) / rows.length) * 100, 100 - pct(num(r[lk]), max)]; });
    var content = [h('div', { class: 'ch-bars' }, rows.map(function (r) { return h('div', { class: 'ch-col' }, h('i', { class: 'soft', title: bk + ' ' + fmt(r[bk], null, p.unit), style: 'height:' + pct(num(r[bk]), max) + '%' })); })),
      h('svg', Object.assign({}, SVGBASE, { class: 'ch-over' }), h('path', { d: pathFor(pts, 'linear', false, 100), class: 'ln s2', fill: 'none', 'vector-effect': 'non-scaling-stroke' }))];
    return shell(p, k, 'Combo chart', 'Combo chart, bars ' + bk + ' and line ' + lk + ' on one axis', [plot(max, hpx(p, k), content, null, p.unit), xLabels(cats, 'cols'), legend([bk, lk])]);
  };

  /* ---------- Waterfall ---------- */
  C.Waterfall = function (p, k) {
    var data = asList(p.data), lb = p.label || 'label', vk = p.value || 'value', subs = asList(p.subtotals), run = 0, steps = [];
    data.forEach(function (r) {
      var label = String(r[lb]), v = num(r[vk]);
      if (subs.indexOf(label) >= 0 || r.total) { if (r.total === undefined && v) run = v; steps.push({ label: label, from: 0, to: run, kind: 'total', shown: run }); }
      else { steps.push({ label: label, from: run, to: run + v, kind: v >= 0 ? 'up' : 'down', shown: v }); run += v; }
    });
    var max = k.domain(niceCeil(Math.max.apply(null, steps.map(function (s) { return Math.max(s.from, s.to); }).concat([1]))));
    var horiz = p.orientation === 'horizontal';
    function sign(s) { return s.kind === 'total' ? fmt(s.shown, p.format) : (s.shown >= 0 ? '+' : '−') + fmt(Math.abs(s.shown), p.format); }
    var cls = { total: 's5', up: 's1', down: 'dn' };
    var body;
    if (horiz) {
      body = h('div', { class: 'ch-hwf' }, steps.map(function (s) {
        var a = Math.min(s.from, s.to), b = Math.max(s.from, s.to);
        return h('div', { class: 'hbar' }, h('span', { class: 'lbl' }, s.label), h('span', { class: 'bar' }, h('i', { class: cls[s.kind], style: 'margin-left:' + pct(a, max) + '%;width:' + pct(b - a, max) + '%' })), h('span', { class: 'v wide' }, sign(s)));
      }));
    } else {
      body = [h('div', { class: 'ch-wf', style: 'height:' + hpx(p, k) + 'px' }, steps.map(function (s, i) {
        var a = Math.min(s.from, s.to), b = Math.max(s.from, s.to), next = steps[i + 1];
        return h('div', { class: 'col' }, h('i', { class: cls[s.kind], title: s.label + ' ' + sign(s), style: 'height:' + pct(b - a, max) + '%;bottom:' + pct(a, max) + '%' }), h('span', { style: 'bottom:calc(' + pct(b, max) + '% + 2px)' }, sign(s)),
          next ? h('u', { class: 'con', style: 'bottom:' + pct(s.to, max) + '%' }) : null);
      })), xLabels(steps.map(function (s) { return s.label; }), 'cols')];
    }
    return shell(p, k, 'Waterfall', 'Waterfall, ' + steps.length + ' steps, ending at ' + fmt(run, p.format), [body, h('div', { class: 'jr-muted ch-note' }, 'Grey bars are totals; increases take the accent, decreases the warning hue, each with a sign.')]);
  };

  /* ---------- Funnel ---------- */
  C.Funnel = function (p, k) {
    var rows = asList(p.data).map(function (r) { return { label: String(r[p.label || 'label']), value: num(r[p.value || 'value']) }; });
    if (p.sort === 'desc') rows.sort(function (a, b) { return b.value - a.value; });
    var max = rows.reduce(function (m, r) { return Math.max(m, r.value); }, 1), show = pickKey(p.show, ['value', 'percent', 'both'], 'value'), start = p.align === 'start', out = [];
    rows.forEach(function (r, i) {
      var prev = rows[i - 1];
      if (i && show !== 'value') out.push(h('div', { class: 'pct' }, round((r.value / (prev.value || 1)) * 100, 0) + ' %'));
      out.push(h('div', { class: 'row' }, h('span', { class: 'lbl' }, r.label), h('span', { class: cx('bar', start && 'start') }, h('i', { style: 'width:' + pct(r.value, max) + '%' })), h('span', { class: 'v' }, show === 'percent' ? round((r.value / max) * 100) + ' %' : fmt(r.value, p.format))));
    });
    return shell(p, k, 'Funnel', 'Funnel, ' + rows.length + ' stages, from ' + (rows[0] ? rows[0].label : '') + ' to ' + (rows.length ? rows[rows.length - 1].label : ''), h('div', { class: 'ch-fun' }, out));
  };

  /* ---------- BoxPlot ---------- */
  function quantile(sorted, q) { var pos = (sorted.length - 1) * q, b = Math.floor(pos), r = pos - b; return sorted[b + 1] !== undefined ? sorted[b] + r * (sorted[b + 1] - sorted[b]) : sorted[b]; }
  C.BoxPlot = function (p, k) {
    var groups = asList(p.data).map(function (r) {
      if (Array.isArray(r.values)) {
        var s = r.values.map(num).sort(function (a, b) { return a - b; }), q1 = quantile(s, 0.25), q3 = quantile(s, 0.75), iqr = q3 - q1;
        var inl = s.filter(function (v) { return v >= q1 - 1.5 * iqr && v <= q3 + 1.5 * iqr; });
        return { name: String(r[p.group || 'group']), min: inl[0], q1: q1, median: quantile(s, 0.5), q3: q3, max: inl[inl.length - 1], out: s.filter(function (v) { return inl.indexOf(v) < 0; }) };
      }
      return { name: String(r[p.group || 'group']), min: num(r.min), q1: num(r.q1), median: num(r.median), q3: num(r.q3), max: num(r.max), out: asList(r.outliers).map(num) };
    });
    var hi = Math.max.apply(null, groups.map(function (g2) { return Math.max(g2.max, Math.max.apply(null, g2.out.concat([0]))); }).concat([1]));
    var max = k.domain(niceCeil(hi)), horiz = p.orientation === 'horizontal', H = hpx(p, k);
    if (horiz) {
      return shell(p, k, 'Box plot', 'Box plot, ' + groups.length + ' groups', h('div', { class: 'ch-hbox' }, groups.map(function (g2) {
        return h('div', { class: 'hbar' }, h('span', { class: 'lbl' }, g2.name), h('span', { class: 'box' }, h('u', { class: 'wh', style: 'left:' + pct(g2.min, max) + '%;width:' + pct(g2.max - g2.min, max) + '%' }),
          h('b', { class: 'bx', style: 'left:' + pct(g2.q1, max) + '%;width:' + pct(g2.q3 - g2.q1, max) + '%' }), h('u', { class: 'md', style: 'left:' + pct(g2.median, max) + '%' }),
          g2.out.map(function (o) { return h('i', { class: 'ot', style: 'left:' + pct(o, max) + '%' }); })), h('span', { class: 'v wide' }, fmt(g2.median, p.format, p.unit)));
      })));
    }
    return shell(p, k, 'Box plot', 'Box plot, ' + groups.length + ' groups', [plot(max, H, h('div', { class: 'ch-bars' }, groups.map(function (g2) {
      return h('div', { class: 'ch-col bp', title: g2.name + ': median ' + fmt(g2.median, p.format, p.unit) }, h('u', { class: 'wh', style: 'bottom:' + pct(g2.min, max) + '%;height:' + pct(g2.max - g2.min, max) + '%' }),
        h('b', { class: 'bx', style: 'bottom:' + pct(g2.q1, max) + '%;height:' + pct(g2.q3 - g2.q1, max) + '%' }), h('u', { class: 'md', style: 'bottom:' + pct(g2.median, max) + '%' }),
        g2.out.map(function (o) { return h('i', { class: 'ot', style: 'bottom:' + pct(o, max) + '%' }); }));
    })), p.format, p.unit), xLabels(groups.map(function (g2) { return g2.name; }), 'cols')]);
  };

  /* ---------- Candlestick ---------- */
  C.Candlestick = function (p, k) {
    var rows = asList(p.data).slice(-180), xk = p.x || 'x', lo = Math.min.apply(null, rows.map(function (r) { return num(r.low); })), hi = Math.max.apply(null, rows.map(function (r) { return num(r.high); }));
    var pad = (hi - lo) * 0.1 || 1, a = lo - pad, b = k.domain(hi + pad), span = b - a, ohlc = p.mark === 'ohlc';
    function y(v) { return ((num(v) - a) / span) * 100; }
    var cats = rows.map(function (r) { return String(r[xk]); });
    var plotEl = h('div', { class: 'ch-plot', style: 'height:' + hpx(p, k) + 'px' },
      h('div', { class: 'ch-ygrid', 'aria-hidden': 'true' }, [0, 0.5, 1].map(function (t) { return h('span', { style: 'bottom:' + t * 100 + '%' }, h('em', null, fmt(a + span * t, p.format))); })),
      h('div', { class: 'ch-area' }, h('div', { class: 'ch-bars' }, rows.map(function (r) {
        var up = num(r.close) >= num(r.open), body = [Math.min(y(r.open), y(r.close)), Math.abs(y(r.close) - y(r.open))];
        return h('div', { class: cx('ch-col cs', up ? 'up' : 'down'), title: String(r[xk]) + ' O ' + r.open + ' H ' + r.high + ' L ' + r.low + ' C ' + r.close },
          h('u', { class: 'wick', style: 'bottom:' + y(r.low) + '%;height:' + (y(r.high) - y(r.low)) + '%' }),
          ohlc ? [h('u', { class: 'tk l', style: 'bottom:' + y(r.open) + '%' }), h('u', { class: 'tk r', style: 'bottom:' + y(r.close) + '%' })] : h('b', { class: 'cb', style: 'bottom:' + body[0] + '%;height:' + Math.max(body[1], 1.5) + '%' }));
      }))));
    return shell(p, k, 'Candlestick', 'Candlestick, ' + rows.length + ' periods, last close ' + (rows.length ? rows[rows.length - 1].close : ''), [plotEl, xLabels(cats, 'cols'),
      h('div', { class: 'ch-leg' }, h('span', null, h('i', { style: 'background:var(--m-good)' }), 'Closed up (filled)'), h('span', null, h('i', { class: 'hollow', style: 'border-color:var(--m-risk)' }), 'Closed down (hollow)'))]);
  };

  /* ---------- Treemap ---------- */
  function squarify(items, rect) {
    var total = items.reduce(function (s, i) { return s + i.value; }, 0) || 1, scale = (rect.w * rect.h) / total;
    var nodes = items.filter(function (i) { return i.value > 0; }).sort(function (a, b) { return b.value - a.value; }).map(function (i) { return { item: i, area: i.value * scale }; });
    var out = [], r = { x: rect.x, y: rect.y, w: rect.w, h: rect.h }, row = [];
    function sum(rw) { return rw.reduce(function (s, n) { return s + n.area; }, 0); }
    function worst(rw, side) {
      var s = sum(rw), mx = Math.max.apply(null, rw.map(function (n) { return n.area; })), mn = Math.min.apply(null, rw.map(function (n) { return n.area; }));
      return Math.max((side * side * mx) / (s * s), (s * s) / (side * side * mn));
    }
    function place(rw) {
      var s = sum(rw);
      if (r.w >= r.h) { var cw = s / r.h, yy = r.y; rw.forEach(function (n) { var hh = n.area / cw; out.push({ item: n.item, x: r.x, y: yy, w: cw, h: hh }); yy += hh; }); r.x += cw; r.w -= cw; }
      else { var rh = s / r.w, xx = r.x; rw.forEach(function (n) { var ww = n.area / rh; out.push({ item: n.item, x: xx, y: r.y, w: ww, h: rh }); xx += ww; }); r.y += rh; r.h -= rh; }
    }
    var i = 0;
    while (i < nodes.length) {
      var n = nodes[i], side = Math.min(r.w, r.h);
      if (!row.length || worst(row.concat([n]), side) <= worst(row, side)) { row.push(n); i++; } else { place(row); row = []; }
    }
    if (row.length) place(row);
    return out;
  }
  JR.squarify = squarify;
  C.Treemap = function (p, k) {
    var W = 240, Hh = 120, items = asList(p.data).map(function (r) { return { label: String(r[p.label || 'label']), value: Math.max(0, num(r[p.value || 'value'])), group: r[p.group || 'group'] }; });
    if (items.length > 200) { items.sort(function (a, b) { return b.value - a.value; }); var rest = items.slice(199); items = items.slice(0, 199).concat([{ label: 'Other', value: rest.reduce(function (s, r2) { return s + r2.value; }, 0), group: 'Other' }]); }
    var groups = [], cells = [];
    items.forEach(function (i) { var gname = i.group === undefined ? '_' : String(i.group); if (groups.indexOf(gname) < 0) groups.push(gname); i.g = gname; });
    var grouped = p.group !== false && groups.length > 1 && (p.maxDepth === undefined || p.maxDepth >= 2);
    if (grouped) {
      var gs = groups.map(function (gname) { var its = items.filter(function (i) { return i.g === gname; }); return { label: gname, value: its.reduce(function (s, i) { return s + i.value; }, 0), items: its }; });
      squarify(gs, { x: 0, y: 0, w: W, h: Hh }).forEach(function (gr) {
        squarify(gr.item.items, { x: gr.x, y: gr.y, w: gr.w, h: gr.h }).forEach(function (c) { cells.push(c); });
      });
    } else cells = squarify(items, { x: 0, y: 0, w: W, h: Hh });
    var minArea = p.minLabelArea || 900;
    return shell(p, k, 'Treemap', 'Treemap, ' + items.length + ' cells, largest ' + (cells[0] ? cells[0].item.label : ''), [
      h('div', { class: 'ch-tm', style: 'height:' + hpx(p, k) + 'px' }, cells.map(function (c) {
        var gi = Math.max(0, groups.indexOf(c.item.g)), isOther = c.item.label === 'Other';
        return h('div', { class: isOther ? 's5' : sCls(gi), title: c.item.label + ': ' + fmt(c.item.value, p.format), style: 'left:' + round((c.x / W) * 100, 2) + '%;top:' + round((c.y / Hh) * 100, 2) + '%;width:' + round((c.w / W) * 100, 2) + '%;height:' + round((c.h / Hh) * 100, 2) + '%' },
          c.w * c.h >= minArea ? [h('b', null, c.item.label), h('span', null, fmt(c.item.value, p.format))] : null);
      })), grouped ? legend(groups) : null]);
  };

  C.Chart = function (p, k) { return C.BarChart(p, k); };

  /* Data not here yet: a skeleton while streaming (axes and three ghost bars), emptyText otherwise. */
  function ghost() {
    return h('div', { class: 'ch ghost', 'aria-hidden': 'true' }, h('div', { class: 'ch-plot', style: 'height:96px' }, h('div', { class: 'ch-ygrid' }, h('span', { style: 'bottom:0' }), h('span', { style: 'bottom:50%' }), h('span', { style: 'bottom:100%' })),
      h('div', { class: 'ch-area' }, h('div', { class: 'ch-bars' }, [60, 85, 40].map(function (hh) { return h('div', { class: 'ch-col' }, h('i', { class: 'sk live', style: 'height:' + hh + '%;background:var(--m-skeleton)' })); })))));
  }
  ['BarChart', 'LineChart', 'AreaChart', 'PieChart', 'Sparkline', 'ScatterChart', 'Heatmap', 'Histogram', 'ComboChart', 'Waterfall', 'Funnel', 'BoxPlot', 'Candlestick', 'Treemap'].forEach(function (name) {
    var fn = C[name];
    C[name] = function (p, k) {
      var d = name === 'Sparkline' || name === 'Histogram' ? p.values : p.data;
      if (!Array.isArray(d)) return k.opts.streaming ? ghost() : h('div', { class: 'ch-empty' }, p.emptyText || 'No data');
      if (!d.length) return h('div', { class: 'ch-empty' }, p.emptyText || 'No data');
      return fn(p, k);
    };
  });
  C.Chart = function (p, k) { return C.BarChart(p, k); };

  JR.charts = { niceCeil: niceCeil, fmt: fmt, squarify: squarify };
})(typeof globalThis !== 'undefined' ? globalThis : this);
