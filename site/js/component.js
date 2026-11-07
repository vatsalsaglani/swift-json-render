/* Component page: ?c=Name. Live preview from the example spec, variants, props, spec, SwiftUI mapping. */
(function (g) {
  'use strict';
  var JR = g.JR, ui = JR.ui, E = JR.engine, doc = g.document, el = ui.el;

  function current() {
    var m = /[?&]c=([^&#]+)/.exec(g.location.search);
    return m ? decodeURIComponent(m[1]) : 'Card';
  }

  function sidebar(reg, name) {
    function build(host, withSearch) {
      if (withSearch) {
        var inp = el('input', { type: 'search', 'data-search': true, placeholder: 'Filter ( / )', 'aria-label': 'Filter components', autocomplete: 'off' });
        host.appendChild(el('div', { class: 'search' }, [inp]));
        inp.addEventListener('input', function () {
          var t = inp.value.trim().toLowerCase();
          [].forEach.call(host.querySelectorAll('a'), function (a) { a.hidden = t && a.textContent.toLowerCase().indexOf(t) < 0; });
          [].forEach.call(host.querySelectorAll('h4'), function (hd) {
            var n = hd.nextSibling, any = false;
            while (n && n.tagName !== 'H4') { if (n.tagName === 'A' && !n.hidden) any = true; n = n.nextSibling; }
            hd.hidden = !any;
          });
        });
      }
      reg.meta.groups.forEach(function (gr) {
        host.appendChild(el('h4', { text: gr.catalog === 'rafu' ? 'Rafu catalog' : gr.label }));
        reg.components.filter(function (c) { return c.group === gr.id; }).forEach(function (c) {
          var a = el('a', { href: ui.href(c.name), text: c.name });
          if (c.name === name) a.setAttribute('aria-current', 'page');
          host.appendChild(a);
        });
      });
    }
    build(doc.getElementById('side'), true);
    build(doc.getElementById('side-inner'), false);
  }

  function propsTable(c) {
    var rows = c.props.map(function (p) {
      var name = el('td', null, [el('code', { text: p.name })]);
      if (p.required) name.appendChild(el('span', { class: 'mini req', text: 'required' }));
      if (p.bindable) name.appendChild(el('span', { class: 'mini', text: '$bindState', title: 'Accepts { "$bindState": "/path" } to write back' }));
      if (p.provisional) name.appendChild(el('span', { class: 'mini draft', text: 'draft', title: 'Named for the mock. The plan names the behaviour, not this prop.' }));
      return el('tr', null, [name, el('td', null, [el('span', { class: 'tt', text: p.type })]), el('td', { text: p.required ? 'yes' : 'no' }), el('td', null, [p.default === null || p.default === undefined ? el('span', { class: 'muted', text: 'none' }) : el('code', { text: JSON.stringify(p.default) })]), el('td', { text: p.note || '' })]);
    });
    if (!rows.length) return el('p', { class: 'muted', text: 'No props. The component takes only children.' });
    var t = el('table', { class: 'props' }, [el('thead', null, [el('tr', null, ['Name', 'Type', 'Required', 'Default', 'Note'].map(function (x) { return el('th', { scope: 'col', text: x }); }))]), el('tbody', null, rows)]);
    return el('div', { class: 'tblwrap', tabindex: '0', role: 'region', 'aria-label': 'Props table' }, [t]);
  }

  function section(id, title, body) {
    return el('section', { class: 'dsec', id: id, 'aria-labelledby': id + '-h' }, [el('h2', { id: id + '-h', text: title })].concat(body));
  }

  function render(reg, c) {
    var page = doc.getElementById('page');
    page.textContent = '';
    var grp = ui.groupOf(c.group), idx = reg.components.indexOf(c);
    var catLabel = { standard: 'Standard catalog', charts: 'Chart family', rafu: 'Rafu catalog' }[c.catalog];
    page.appendChild(el('nav', { class: 'crumbs', 'aria-label': 'Breadcrumb' }, [el('a', { href: 'index.html#components', text: 'Components' }), '/', el('span', { text: catLabel }), '/', el('span', { text: grp.label })]));
    page.appendChild(el('div', { class: 'dhead' }, [el('h1', { text: c.name }), el('span', { class: 'pill ' + (c.catalog === 'rafu' ? 'warn' : c.catalog === 'charts' ? 'good' : 'plain'), text: c.catalog === 'rafu' ? 'Rafu catalog' : catLabel })].concat(c.moved ? [el('span', { class: 'pill warn', text: 'Moved' })] : [])));
    page.appendChild(el('p', { class: 'dsum', text: c.description }));
    var facts = el('div', { class: 'facts-row' });
    facts.appendChild(el('span', null, [el('b', { text: 'Events: ' }), c.events.length ? c.events.join(', ') : 'none']));
    facts.appendChild(el('span', null, [el('b', { text: 'Slots: ' }), c.slots.length ? c.slots.join(', ') : 'none']));
    facts.appendChild(el('span', null, [el('b', { text: 'Variants: ' }), String(c.variants.length)]));
    page.appendChild(facts);
    if (c.catalog === 'rafu') page.appendChild(el('div', { class: 'callout warn', role: 'note' }, [el('p', { text: 'Rafu catalog. This component is not part of the open-source standard catalog. Rafu registers it on top.' })]));
    page.appendChild(el('nav', { class: 'subnav', 'aria-label': 'On this page' }, [['preview', 'Preview'], ['variants', 'Variants'], ['props', 'Props'], ['spec', 'Spec'], ['swiftui', 'SwiftUI']].map(function (x) { return el('a', { href: '#' + x[0], text: x[1] }); })));

    /* preview with example tabs, state and action log */
    var exIndex = 0, liveApi = null;
    var mockBody = el('div'), mock = el('div', { class: 'mock' }, [mockBody]);
    var stateOut = el('pre', { tabindex: '0', 'aria-label': 'Current state' }), logOut = el('ol', { 'aria-label': 'Emitted actions' });
    var desc = el('p', { class: 'small', style: 'margin:0 0 10px' }), tabsBar = el('div', { class: 'codebar', role: 'tablist', 'aria-label': 'Examples' });
    var specHost = el('div');
    function onDraw(store) {
      var txt = JSON.stringify(store.state, null, 2);
      stateOut.textContent = txt.length > 1600 ? txt.slice(0, 1600) + '\n...' : txt;
      logOut.textContent = '';
      var log = store.log.slice(-6).reverse();
      if (!log.length) logOut.appendChild(el('li', { class: 'none', text: 'No actions yet. Use the preview.' }));
      log.forEach(function (e) { logOut.appendChild(el('li', { text: e.action + '(' + JSON.stringify(e.params).slice(0, 90) + ')' + (e.builtin ? '' : ' -> host') })); });
    }
    function showExample(i) {
      exIndex = i;
      var ex = c.examples[i];
      [].forEach.call(tabsBar.children, function (b, j) { b.setAttribute('aria-selected', j === i ? 'true' : 'false'); b.tabIndex = j === i ? 0 : -1; });
      desc.textContent = ex.description || '';
      liveApi = ui.live(mockBody, E.clone(ex.spec), { onDraw: onDraw });
      specHost.textContent = '';
      specHost.appendChild(ui.codeBox(JSON.stringify(ex.spec, null, 2), 'json', { label: 'example spec ' + (ex.title || '') }));
    }
    c.examples.forEach(function (ex, i) {
      var b = el('button', { type: 'button', class: 'tab-btn', role: 'tab', text: ex.title || 'Example ' + (i + 1) });
      b.addEventListener('click', function () { showExample(i); });
      b.addEventListener('keydown', function (e) {
        var d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
        if (!d) return;
        var n = (i + d + c.examples.length) % c.examples.length;
        showExample(n); tabsBar.children[n].focus(); e.preventDefault();
      });
      tabsBar.appendChild(b);
    });
    var reset = el('button', { type: 'button', class: 'icon-btn', text: 'Reset state' });
    reset.addEventListener('click', function () { if (liveApi) liveApi.store.reset(); });
    var stage = el('div', { class: 'stage' }, [mock]);
    var insp = el('div', { class: 'insp' }, [el('h4', { text: 'State' }), stateOut, el('h4', { text: 'Actions' }), logOut]);
    page.appendChild(section('preview', 'Live preview', [
      el('p', { class: 'section-lede', text: 'Drawn from the example spec below by a small interpreter. Inputs write to state, and other elements read it back.' }),
      el('div', { class: 'demo-bar' }, [tabsBar, reset]), desc, el('div', { class: 'demo' }, [stage, insp])]));

    /* variants */
    var vBody;
    if (!c.variants.length) vBody = el('p', { class: 'muted', text: 'No named variants. The props table lists every option.' });
    else {
      vBody = el('div', { class: 'vgrid' });
      c.variants.forEach(function (v) {
        var host = el('div'), box = el('div', { class: 'mock' }, [host]);
        vBody.appendChild(el('figure', { class: 'vcell', style: 'margin:0' }, [el('div', { class: 'box' }, [box]), el('figcaption', null, [v.label, el('span', { class: 'muted', text: v.note ? ' · ' + v.note : '' })])]));
        ui.live(host, ui.variantSpec(c, v), {});
      });
    }
    page.appendChild(section('variants', 'Variants side by side', [vBody]));

    /* props, events, slots */
    var pb = [el('p', { class: 'small', text: 'Every prop also accepts an expression, such as { "$state": "/path" }, { "$template": "..." } or { "$cond": ... }.' }), propsTable(c)];
    page.appendChild(section('props', 'Props', pb));

    /* spec */
    page.appendChild(section('spec', 'Example spec', [el('p', { class: 'section-lede', text: 'The upstream element shape: root, elements by id with type, props, children and visible, and optional state. Copy it into any json-render host.' }), specHost]));

    /* swiftui */
    page.appendChild(section('swiftui', 'SwiftUI mapping', [
      el('p', { text: c.swiftui }),
      el('h4', { text: 'Catalog definition', style: 'margin-top:18px' }),
      el('p', { class: 'small', text: 'Planned API. Generated from the registry. The final form comes from Catalog.jsonSchema().' }),
      ui.codeBox(ui.swiftDef(c), 'swift', { label: 'catalog definition' })]));

    var prev = reg.components[(idx - 1 + reg.components.length) % reg.components.length], next = reg.components[(idx + 1) % reg.components.length];
    page.appendChild(el('nav', { class: 'pn', 'aria-label': 'Previous and next component' }, [
      el('a', { href: ui.href(prev.name), rel: 'prev' }, [el('small', { text: 'Previous (k)' }), prev.name]),
      el('a', { href: ui.href(next.name), rel: 'next', style: 'text-align:right' }, [el('small', { text: 'Next (j)' }), next.name])]));

    showExample(0);
    doc.title = c.name + ' · swift-json-render';
    return { prev: prev, next: next };
  }

  ui.ready(function () {
    ui.initTheme();
    var reg = JR.registry, name = current(), c = ui.byName(name);
    sidebar(reg, c ? c.name : '');
    if (!c) {
      doc.getElementById('page').appendChild(el('div', { class: 'empty' }, [el('p', { text: 'No component named "' + name + '".' }), el('a', { href: 'index.html#components', text: 'See all components' })]));
      ui.initKeys();
      return;
    }
    var nav = render(reg, c);
    ui.initKeys(function (e) {
      if (e.key === 'j') g.location.href = ui.href(nav.next.name);
      else if (e.key === 'k') g.location.href = ui.href(nav.prev.name);
    });
  });
})(typeof globalThis !== 'undefined' ? globalThis : this);
