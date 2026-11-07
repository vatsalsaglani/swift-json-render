/* Mini json-render interpreter core: state store, expressions, visibility, actions, SpecStream.
   Supports $state, $bindState, $item, $bindItem, $index, $cond, $template, visible, repeat,
   setState, toggleState, incrementState, pushState, removeState. Specs never contain code. */
(function (g) {
  'use strict';
  var JR = (g.JR = g.JR || {});
  var BLOCKED = { __proto__: 1, constructor: 1, prototype: 1 };

  function clone(v) {
    return v === undefined ? undefined : JSON.parse(JSON.stringify(v));
  }

  /* ---------- JSON Pointer (RFC 6901) ---------- */
  function parts(ptr) {
    if (ptr === '' || ptr === null || ptr === undefined) return [];
    ptr = String(ptr);
    if (ptr.charAt(0) !== '/') ptr = '/' + ptr;
    return ptr
      .split('/')
      .slice(1)
      .map(function (s) {
        return s.replace(/~1/g, '/').replace(/~0/g, '~');
      });
  }

  function getAt(obj, ptr) {
    var cur = obj, p = parts(ptr);
    for (var i = 0; i < p.length; i++) {
      if (cur === null || cur === undefined || typeof cur !== 'object') return undefined;
      cur = cur[p[i]];
    }
    return cur;
  }

  /* Returns a new root with the value set. Copies along the path, never leaves array holes. */
  function setAt(obj, ptr, value) {
    var p = parts(ptr);
    if (!p.length) return value;
    for (var i = 0; i < p.length; i++) if (BLOCKED[p[i]]) throw new Error('blocked path segment ' + p[i]);
    var root = Array.isArray(obj) ? obj.slice() : Object.assign({}, obj);
    var cur = root;
    for (var j = 0; j < p.length - 1; j++) {
      var k = p[j], next = cur[k];
      if (next === null || typeof next !== 'object') next = /^\d+$/.test(p[j + 1]) ? [] : {};
      else next = Array.isArray(next) ? next.slice() : Object.assign({}, next);
      cur[k] = next;
      cur = next;
    }
    var last = p[p.length - 1];
    if (Array.isArray(cur)) {
      if (last === '-') cur.push(value);
      else cur[Math.min(Number(last), cur.length)] = value;
    } else cur[last] = value;
    return root;
  }

  function removeAt(obj, ptr) {
    var p = parts(ptr);
    if (!p.length) return obj;
    var parent = getAt(obj, '/' + p.slice(0, -1).join('/'));
    if (p.length === 1) parent = obj;
    if (parent === null || typeof parent !== 'object') return obj;
    var copy = clone(parent), last = p[p.length - 1];
    if (Array.isArray(copy)) copy.splice(Number(last), 1);
    else delete copy[last];
    return p.length === 1 ? copy : setAt(obj, '/' + p.slice(0, -1).join('/'), copy);
  }

  /* ---------- Store ---------- */
  function createStore(initial) {
    var init = clone(initial || {});
    var state = clone(init);
    var ui = {};
    var subs = [];
    var log = [];
    function emit() {
      subs.slice().forEach(function (f) { f(); });
    }
    var store = {
      get state() { return state; },
      get: function (ptr) { return getAt(state, ptr); },
      set: function (ptr, v) {
        state = setAt(state, ptr, v);
        emit();
      },
      replaceState: function (s) { state = s; emit(); },
      notify: emit,
      reset: function () { state = clone(init); ui = {}; log = []; emit(); },
      ui: function (key, def) { return key in ui ? ui[key] : def; },
      setUi: function (key, v) { ui[key] = v; emit(); },
      get log() { return log; },
      note: function (entry) { log.push(entry); if (log.length > 40) log.shift(); },
      subscribe: function (f) { subs.push(f); return function () { subs = subs.filter(function (x) { return x !== f; }); }; }
    };
    return store;
  }

  /* ---------- Expressions ---------- */
  function itemField(ctx, field) {
    if (field === '' || field === true) return ctx.item;
    return getAt(ctx.item, '/' + String(field).replace(/\./g, '/'));
  }

  function template(str, ctx) {
    return String(str).replace(/\$\{([^}]+)\}/g, function (_, key) {
      key = key.trim();
      var v;
      if (key.charAt(0) === '/') v = getAt(ctx.state, key);
      else {
        v = ctx.item !== undefined ? itemField(ctx, key) : undefined;
        if (v === undefined) v = getAt(ctx.state, '/' + key);
      }
      if (v === undefined || v === null) return '';
      return typeof v === 'object' ? JSON.stringify(v) : String(v);
    });
  }

  function resolve(v, ctx) {
    if (Array.isArray(v)) return v.map(function (x) { return resolve(x, ctx); });
    if (v && typeof v === 'object') {
      if ('$state' in v) return getAt(ctx.state, v.$state);
      if ('$bindState' in v) return getAt(ctx.state, v.$bindState);
      if ('$item' in v) return itemField(ctx, v.$item);
      if ('$bindItem' in v) return itemField(ctx, v.$bindItem);
      if ('$index' in v) return ctx.index;
      if ('$cond' in v) return evalCond(v.$cond, ctx) ? resolve(v.$then, ctx) : resolve(v.$else, ctx);
      if ('$template' in v) return template(v.$template, ctx);
      if ('$computed' in v) return undefined; /* host-registered functions only; none in the showcase */
      var out = {};
      Object.keys(v).forEach(function (k) { out[k] = resolve(v[k], ctx); });
      return out;
    }
    return v;
  }

  /* Pointer a value writes back to, or null. */
  function bindingPath(v, ctx) {
    if (v && typeof v === 'object' && !Array.isArray(v)) {
      if ('$bindState' in v) return String(v.$bindState);
      if ('$bindItem' in v) return (ctx.basePath || '') + '/' + String(v.$bindItem).replace(/\./g, '/');
    }
    return null;
  }

  function resolveProps(props, ctx) {
    var out = {}, bindings = {};
    Object.keys(props || {}).forEach(function (k) {
      out[k] = resolve(props[k], ctx);
      var b = bindingPath(props[k], ctx);
      if (b) bindings[k] = b;
    });
    return { props: out, bindings: bindings };
  }

  /* ---------- Visibility ---------- */
  function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
  }

  function evalCond(c, ctx) {
    if (c === true || c === false) return c;
    if (c === undefined || c === null) return true;
    if (Array.isArray(c)) return c.every(function (x) { return evalCond(x, ctx); });
    if (typeof c !== 'object') return !!c;
    if ('$and' in c) return c.$and.every(function (x) { return evalCond(x, ctx); });
    if ('$or' in c) return c.$or.some(function (x) { return evalCond(x, ctx); });
    var subject;
    if ('$state' in c) subject = getAt(ctx.state, c.$state);
    else if ('$item' in c) subject = itemField(ctx, c.$item);
    else if ('$index' in c) subject = ctx.index;
    else return true;
    var ops = ['eq', 'neq', 'gt', 'gte', 'lt', 'lte'], result = !!subject;
    for (var i = 0; i < ops.length; i++) {
      var op = ops[i];
      if (!(op in c)) continue;
      var rhs = resolve(c[op], ctx);
      if (op === 'eq') result = same(subject, rhs);
      else if (op === 'neq') result = !same(subject, rhs);
      else if (op === 'gt') result = subject > rhs;
      else if (op === 'gte') result = subject >= rhs;
      else if (op === 'lt') result = subject < rhs;
      else result = subject <= rhs;
      break;
    }
    return c.not ? !result : result;
  }

  /* ---------- Actions ---------- */
  /* In action params, $item resolves to the absolute state path (plan section 6). */
  function resolveParam(v, ctx) {
    if (Array.isArray(v)) return v.map(function (x) { return resolveParam(x, ctx); });
    if (v && typeof v === 'object') {
      if ('$item' in v) return (ctx.basePath || '') + (v.$item === '' ? '' : '/' + String(v.$item).replace(/\./g, '/'));
      if ('$state' in v || '$cond' in v || '$template' in v || '$index' in v || '$bindState' in v) return resolve(v, ctx);
      var out = {};
      Object.keys(v).forEach(function (k) { out[k] = resolveParam(v[k], ctx); });
      return out;
    }
    return v;
  }

  var idCounter = 0;
  function runAction(binding, ctx, store) {
    if (!binding) return;
    if (Array.isArray(binding)) { binding.forEach(function (b) { runAction(b, ctx, store); }); return; }
    var name = binding.action, params = resolveParam(binding.params || {}, ctx);
    var path = params.statePath, cur;
    if (name === 'setState') store.set(path, params.value);
    else if (name === 'toggleState') store.set(path, !store.get(path));
    else if (name === 'incrementState') {
      cur = Number(store.get(path)) || 0;
      store.set(path, cur + (params.by === undefined ? 1 : Number(params.by)));
    } else if (name === 'pushState') {
      var val = params.value;
      if (val && typeof val === 'object' && val.id === '$id') val = Object.assign({}, val, { id: 'id-' + ++idCounter });
      store.set(String(path) + '/-', val);
      if (params.clearStatePath) store.set(params.clearStatePath, '');
    } else if (name === 'removeState') {
      var arr = store.get(path);
      if (Array.isArray(arr)) {
        var next = arr.slice();
        next.splice(Number(params.index), 1);
        store.set(path, next);
      }
    } else {
      store.note({ action: name, params: params });
      store.notify();
      return;
    }
    store.note({ action: name, params: params, builtin: true });
  }

  /* ---------- SpecStream (JSONL of RFC 6902 patches) ---------- */
  function parseSpecStream(textIn) {
    var patches = [], bad = [];
    String(textIn).split('\n').forEach(function (line, i) {
      var t = line.trim();
      if (!t || t.charAt(0) !== '{') return;
      try { patches.push({ line: i, patch: JSON.parse(t), raw: t }); }
      catch (e) { bad.push({ line: i, reason: 'not valid JSON', raw: t }); }
    });
    return { patches: patches, bad: bad };
  }

  function addAt(doc, ptr, value) {
    var p = parts(ptr);
    if (!p.length) return value;
    return setAt(doc, ptr, value);
  }

  function applyPatch(doc, op) {
    var kind = op.op, path = op.path;
    if (kind === 'add') {
      var p = parts(path), parent = getAt(doc, '/' + p.slice(0, -1).join('/'));
      if (Array.isArray(parent) && p[p.length - 1] !== '-') {
        var copy = parent.slice();
        copy.splice(Number(p[p.length - 1]), 0, op.value);
        return p.length === 1 ? copy : setAt(doc, '/' + p.slice(0, -1).join('/'), copy);
      }
      return addAt(doc, path, op.value);
    }
    if (kind === 'replace') return setAt(doc, path, op.value); /* tolerant: sets even if missing, as upstream */
    if (kind === 'remove') return removeAt(doc, path);
    if (kind === 'copy') return addAt(doc, path, clone(getAt(doc, op.from)));
    if (kind === 'move') {
      var v = clone(getAt(doc, op.from));
      return addAt(removeAt(doc, op.from), path, v);
    }
    if (kind === 'test') {
      if (!same(getAt(doc, path), op.value)) throw new Error('test failed at ' + path);
      return doc;
    }
    throw new Error('unknown op ' + kind);
  }

  /* Apply the first n patches to an empty spec. Returns {spec, journal}. */
  function compileStream(patches, n) {
    var doc = { elements: {} }, journal = [];
    for (var i = 0; i < Math.min(n, patches.length); i++) {
      try { doc = applyPatch(doc, patches[i].patch); }
      catch (e) { journal.push({ line: patches[i].line, reason: e.message }); }
    }
    return { spec: doc, journal: journal };
  }

  /* Elements referenced but absent (children and slots), reachable from the root. */
  function danglingIds(spec) {
    var out = [], seen = {};
    function walk(id) {
      if (seen[id]) return;
      seen[id] = true;
      var el = spec.elements && spec.elements[id];
      if (!el) { out.push(id); return; }
      (el.children || []).forEach(walk);
      Object.keys(el.slots || {}).forEach(function (s) { el.slots[s].forEach(walk); });
    }
    if (spec.root) walk(spec.root);
    return out;
  }

  JR.engine = {
    clone: clone, getAt: getAt, setAt: setAt, removeAt: removeAt, parts: parts,
    createStore: createStore, resolve: resolve, resolveProps: resolveProps, bindingPath: bindingPath,
    evalCond: evalCond, runAction: runAction, template: template, itemField: itemField,
    parseSpecStream: parseSpecStream, applyPatch: applyPatch, compileStream: compileStream, danglingIds: danglingIds
  };
})(typeof globalThis !== 'undefined' ? globalThis : this);
