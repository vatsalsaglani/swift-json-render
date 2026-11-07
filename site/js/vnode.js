/* Tiny virtual-node layer. Works in the browser (classic script) and in node (require).
   h() builds a vnode, toHTML() serialises it for tests, mount() patches a DOM container. */
(function (g) {
  'use strict';
  var JR = (g.JR = g.JR || {});
  var SVG_NS = 'http://www.w3.org/2000/svg';
  var SVG = { svg: 1, path: 1, polyline: 1, polygon: 1, line: 1, circle: 1, rect: 1, g: 1, text: 1, defs: 1 };
  var VOID = { input: 1, br: 1, hr: 1, img: 1 };

  function flat(list, out) {
    for (var i = 0; i < list.length; i++) {
      var c = list[i];
      if (c === null || c === undefined || c === false || c === true) continue;
      if (Array.isArray(c)) flat(c, out);
      else out.push(typeof c === 'object' ? c : String(c));
    }
    return out;
  }

  /* h(tag, attrs, ...children). attrs: class, style, on:{event:fn}, p:{domProperty:value}, any other key is an attribute. */
  function h(tag, attrs) {
    var kids = flat(Array.prototype.slice.call(arguments, 2), []);
    return { t: tag, a: attrs || {}, c: kids };
  }

  function esc(s) {
    return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
  }

  function attrList(v) {
    var a = v.a, out = [];
    for (var k in a) {
      if (k === 'on' || k === 'p') continue;
      var val = a[k];
      if (val === null || val === undefined || val === false) continue;
      out.push(val === true ? k : k + '="' + esc(val) + '"');
    }
    var p = v.a.p || {};
    if (p.value !== undefined && v.t === 'input') out.push('value="' + esc(p.value) + '"');
    if (p.checked) out.push('checked');
    if (p.disabled) out.push('disabled');
    return out;
  }

  function toHTML(v) {
    if (v === null || v === undefined) return '';
    if (typeof v === 'string') return esc(v);
    var attrs = attrList(v);
    var open = '<' + v.t + (attrs.length ? ' ' + attrs.join(' ') : '') + '>';
    if (VOID[v.t]) return open;
    var inner = v.c.map(toHTML).join('');
    if (v.t === 'textarea' && v.a.p && v.a.p.value !== undefined) inner = esc(v.a.p.value);
    return open + inner + '</' + v.t + '>';
  }

  function text(v) {
    if (typeof v === 'string') return v;
    return v.c.map(text).join('');
  }

  function count(v) {
    if (typeof v === 'string') return 0;
    var n = 1;
    for (var i = 0; i < v.c.length; i++) n += count(v.c[i]);
    return n;
  }

  /* ---------- DOM (browser only) ---------- */
  function setAttr(el, k, val) {
    if (val === null || val === undefined || val === false) el.removeAttribute(k);
    else el.setAttribute(k, val === true ? '' : String(val));
  }

  function applyProps(el, oldP, newP) {
    for (var k in newP) {
      var val = newP[k];
      if (k === 'value') {
        if (el.value !== String(val === undefined || val === null ? '' : val)) el.value = val === undefined || val === null ? '' : val;
      } else if (el[k] !== val) el[k] = val;
    }
  }

  function applyEvents(el, ev) {
    el.__e = ev || {};
    el.__l = el.__l || {};
    for (var type in el.__e) {
      if (el.__l[type]) continue;
      el.__l[type] = true;
      (function (t) {
        el.addEventListener(t, function (e) {
          var f = el.__e && el.__e[t];
          if (f) f(e);
        });
      })(type);
    }
  }

  function applyAttrs(el, oldA, newA) {
    var k;
    for (k in oldA) if (k !== 'on' && k !== 'p' && !(k in newA)) el.removeAttribute(k);
    for (k in newA) {
      if (k === 'on' || k === 'p') continue;
      if (oldA[k] !== newA[k]) setAttr(el, k, newA[k]);
    }
  }

  function create(v) {
    if (typeof v === 'string') return document.createTextNode(v);
    var el = SVG[v.t] ? document.createElementNS(SVG_NS, v.t) : document.createElement(v.t);
    applyAttrs(el, {}, v.a);
    for (var i = 0; i < v.c.length; i++) el.appendChild(create(v.c[i]));
    if (v.a.p) applyProps(el, {}, v.a.p);
    if (v.a.on) applyEvents(el, v.a.on);
    return el;
  }

  /* Fresh nodes inside [data-fade] get a 180 ms fade (the streaming reveal). CSS drops it under Reduce Motion. */
  function fresh(el, parent) {
    if (el.nodeType === 1 && parent && parent.closest && parent.closest('[data-fade]')) el.classList.add('fadein');
    return el;
  }

  function patch(dom, oldV, newV) {
    if (typeof newV === 'string' || typeof oldV === 'string') {
      if (typeof newV === 'string' && typeof oldV === 'string') {
        if (oldV !== newV) dom.nodeValue = newV;
        return dom;
      }
      var made = fresh(create(newV), dom.parentNode);
      dom.parentNode.replaceChild(made, dom);
      return made;
    }
    if (oldV.t !== newV.t) {
      var el = fresh(create(newV), dom.parentNode);
      dom.parentNode.replaceChild(el, dom);
      return el;
    }
    applyAttrs(dom, oldV.a, newV.a);
    var n = Math.max(oldV.c.length, newV.c.length);
    for (var i = 0; i < n; i++) {
      if (i >= oldV.c.length) dom.appendChild(fresh(create(newV.c[i]), dom));
      else if (i < newV.c.length) patch(dom.childNodes[i], oldV.c[i], newV.c[i]);
    }
    while (dom.childNodes.length > newV.c.length) dom.removeChild(dom.lastChild);
    if (newV.a.p) applyProps(dom, oldV.a.p || {}, newV.a.p);
    applyEvents(dom, newV.a.on);
    return dom;
  }

  function mount(container, vnode) {
    if (!container.__v || !container.firstChild) {
      container.textContent = '';
      container.appendChild(create(vnode));
    } else {
      patch(container.firstChild, container.__v, vnode);
    }
    container.__v = vnode;
  }

  JR.h = h;
  JR.toHTML = toHTML;
  JR.vtext = text;
  JR.vcount = count;
  JR.mount = mount;
  JR.esc = esc;
})(typeof globalThis !== 'undefined' ? globalThis : this);
