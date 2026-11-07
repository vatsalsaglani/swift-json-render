// usage: node build-cases.mjs <clone> <stage> <npmDir>
// Builds the hand-transcribed parity folders. Each case lives in cases/*.mjs with its input and
// (where the upstream test asserts one) its expected value. Every case is executed against the
// published @json-render/core 0.22.0 and the build fails if the transcribed expectation differs.
// Outputs written when no expectation was transcribed (streams, validator issue lists) come
// from that run. No eval, no network.
import fs from "node:fs";
import path from "node:path";
import { createRequire } from "node:module";
import { pathToFileURL, fileURLToPath } from "node:url";
import { createStage, jsonEqual, encode, decode } from "./lib.mjs";

const [clone, stageDir, npmDir] = process.argv.slice(2);
const here = path.dirname(fileURLToPath(import.meta.url));
const req = createRequire(path.join(npmDir, "noop.js"));
const core = await import(req.resolve("@json-render/core"));
const storeUtils = await import(req.resolve("@json-render/core/store-utils"));
const { z } = await import(req.resolve("zod"));
console.warn = () => {}; // upstream warns on purpose for unknown functions; keep the log quiet
const stage = createStage(stageDir, clone);

const caseModule = async (n) => import(pathToFileURL(path.join(here, "cases", `${n}.mjs`)).href);

// ---- source references -------------------------------------------------------------------
const IT = /\bit(\.each\([^)]*\))?\(/;
function resolveSrc(ref) {
  const m = ref.match(/^([^#:]+)(?:#(.*)|:(\d+)(?:-(\d+))?)$/);
  if (!m) throw new Error(`bad src ${ref}`);
  const file = m[1];
  const ls = stage.lines(file);
  if (m[2] === undefined) {
    return { upstreamPath: file, upstreamLines: `${m[3]}-${m[4] ?? m[3]}`, upstreamTest: `${path.basename(file)}:${m[3]}` };
  }
  const [frag, ctx] = m[2].split("|");
  let from = 0;
  if (ctx) {
    from = ls.findIndex((l) => l.includes("describe(") && l.includes(ctx));
    if (from < 0) throw new Error(`context not found: ${ref}`);
  }
  let start = -1;
  for (let i = from; i < ls.length; i++) {
    if (IT.test(ls[i]) && (ls[i] + (ls[i + 1] ?? "")).includes(frag)) { start = i + 1; break; }
  }
  if (start < 0) throw new Error(`test not found: ${ref}`);
  const loc = stage.locate(`${file}:${start}`);
  return { ...loc, upstreamTest: `${path.basename(file)}:${start}` };
}

const names = new Set();
function emit(folder, name, files, src, kind, extraIndex = {}) {
  const key = `${folder}/${name}`;
  if (names.has(key)) throw new Error(`duplicate case ${key}`);
  names.add(key);
  const loc = resolveSrc(src);
  const entry = { kind, upstreamPath: loc.upstreamPath, upstreamLines: loc.upstreamLines };
  for (const [rel, content] of Object.entries(files)) {
    const p = `${folder}/${rel}`;
    if (typeof content === "string") stage.write(p, content, entry);
    else stage.writeJSON(p, content, entry);
  }
  return { upstreamTest: loc.upstreamTest, ...extraIndex };
}
function writeIndex(folder, rows) {
  stage.writeJSON(`${folder}/index.json`, rows, {
    kind: "index", upstreamPath: "(case list)", upstreamLines: "each row names its upstream test in upstreamTest",
  });
}
function expectEqual(label, real, wanted) {
  if (!jsonEqual(real, decode(wanted))) {
    throw new Error(`${label}: transcribed expectation differs from upstream run\n real:   ${JSON.stringify(encode(real))}\n wanted: ${JSON.stringify(wanted)}`);
  }
}

// ---- state ---------------------------------------------------------------------------------
{
  const { state } = await caseModule("state");
  const rows = [];
  for (const c of state) {
    const st = structuredClone(c.initial);
    for (const [i, op] of c.ops.entries()) {
      const label = `state/${c.name} op ${i}`;
      const run = () => {
        switch (op.op) {
          case "set": core.setByPath(st, op.path, decode(op.value)); return undefined;
          case "add": core.addByPath(st, op.path, decode(op.value)); return undefined;
          case "remove": core.removeByPath(st, op.path); return undefined;
          case "get": return core.getByPath(st, op.path);
          case "patch": core.applySpecStreamPatch(st, op.patch); return undefined;
          case "resolveRepeatStatePath": return core.resolveRepeatStatePath(decode(op.value), op.base);
          case "resolveRepeatItemStatePath": return core.resolveRepeatItemStatePath(op.base, op.index);
          case "flatten": return storeUtils.flattenToPointers(st);
          case "findFormValue": return core.findFormValue(op.field, decode(op.params), decode(op.state));
          default: throw new Error(`${label}: unknown op ${op.op}`);
        }
      };
      if (op.throws !== undefined) {
        let msg = null;
        try { run(); } catch (e) { msg = e.message; }
        if (msg === null) throw new Error(`${label}: expected a throw`);
        if (typeof op.throws === "string" && !msg.includes(op.throws)) throw new Error(`${label}: wrong throw ${msg}`);
      } else {
        const r = run();
        if ("expect" in op) expectEqual(label, r, op.expect);
      }
    }
    if (({}).polluted !== undefined || typeof Object.prototype.toString !== "function") throw new Error("prototype polluted");
    expectEqual(`state/${c.name} final`, st, c.expected);
    const file = `${c.name}.json`;
    const ops = c.ops.map((o) => (o.throws === undefined && o.op !== "get" && !("expect" in o) ? o : o));
    const idx = emit("state", c.name, { [file]: { initial: c.initial, ops, expected: c.expected } }, c.src, "state", { file, name: c.name });
    rows.push({ name: c.name, file, ...idx });
  }
  writeIndex("state", rows);
}

// ---- streams -------------------------------------------------------------------------------
{
  const { streams } = await caseModule("streams");
  const rows = [];
  for (const c of streams) {
    const chunks = c.chunks ?? [c.input];
    const input = chunks.join("");
    const lineSet = () => input.split("\n").map((l) => core.parseSpecStreamLine(l)).filter(Boolean);
    let folder = "streams";
    let files;
    let row;
    if (c.kind === "mixed") {
      const events = [];
      const parser = core.createMixedStreamParser({
        onPatch: (p) => events.push({ kind: "patch", value: p }),
        onText: (t) => events.push({ kind: "text", value: t }),
      });
      for (const ch of chunks) parser.push(ch);
      if (c.flush) parser.flush();
      files = { [`mixed/${c.name}.txt`]: input, [`mixed/${c.name}.expected.json`]: { chunks, flush: c.flush ?? false, events } };
      row = { name: c.name, kind: "mixed", input: `mixed/${c.name}.txt`, expected: `mixed/${c.name}.expected.json` };
    } else {
      let expected;
      if (c.kind === "compile") {
        const result = core.compileSpecStream(input, structuredClone(c.initial ?? {}));
        expected = { result, patches: lineSet(), ...(c.initial ? { initial: c.initial } : {}) };
      } else if (c.kind === "compiler") {
        const comp = core.createSpecStreamCompiler();
        const pushes = chunks.map((ch) => ({ newPatches: comp.push(ch).newPatches.length }));
        if (c.reset) comp.reset();
        const result = comp.getResult();
        expected = { chunks, pushes, ...(c.reset ? { reset: true } : {}), result, patches: comp.getPatches() };
      } else if (c.kind === "spec-patch") {
        const spec = structuredClone(c.initial);
        const ps = lineSet();
        for (const p of ps) core.applySpecPatch(spec, p);
        expected = { initial: c.initial, patches: ps, result: spec, applier: "applySpecPatch" };
      } else throw new Error(`unknown stream kind ${c.kind}`);
      files = { [`${c.name}.jsonl`]: input, [`${c.name}.expected.json`]: expected };
      row = { name: c.name, kind: c.kind, input: `${c.name}.jsonl`, expected: `${c.name}.expected.json` };
    }
    const idx = emit(folder, c.name, files, c.src, c.kind === "mixed" ? "stream-mixed" : "stream");
    rows.push({ ...row, ...idx });
  }
  writeIndex("streams", rows);
}

// ---- validator -----------------------------------------------------------------------------
{
  const { validator } = await caseModule("validator");
  const rows = [];
  for (const c of validator) {
    const options = { checkOrphans: c.options?.checkOrphans ?? false };
    let expected;
    if (c.kind === "validate") {
      const r = core.validateSpec(structuredClone(c.spec), c.options);
      const codes = r.issues.map((i) => i.code).sort();
      for (const h of c.has) if (!codes.includes(h)) throw new Error(`validator/${c.name}: missing ${h}; got ${codes}`);
      if (c.exact && JSON.stringify(codes) !== JSON.stringify([...c.has].sort())) throw new Error(`validator/${c.name}: codes ${codes}`);
      for (const [code, n] of Object.entries(c.counts ?? {})) {
        if (codes.filter((x) => x === code).length !== n) throw new Error(`validator/${c.name}: count of ${code}`);
      }
      if (c.firstCode && r.issues[0].code !== c.firstCode) throw new Error(`validator/${c.name}: first code`);
      if (c.elementKey && !r.issues.some((i) => i.elementKey === c.elementKey && i.code === c.has[0])) throw new Error(`validator/${c.name}: elementKey`);
      if (c.slotMessageContains && !r.issues.some((i) => i.message.includes(c.slotMessageContains))) throw new Error(`validator/${c.name}: slot message`);
      expected = {
        valid: r.valid, codes, options,
        issues: r.issues.map((i) => ({ code: i.code, severity: i.severity, elementKey: i.elementKey, message: i.message })),
        ...(c.exact ? {} : { partial: true, asserted: c.has }),
        ...(c.counts ? { counts: c.counts } : {}),
      };
    } else {
      const r = core.autoFixSpec(structuredClone(c.spec), c.options);
      expected = { autoFix: true, options: c.options ?? {}, fixes: r.fixes, fixDetails: r.fixDetails, fixed: r.spec,
        validAfterFix: core.validateSpec(structuredClone(r.spec)).valid };
    }
    const idx = emit("validator", c.name, { [`${c.name}.spec.json`]: c.spec, [`${c.name}.expected.json`]: expected }, c.src, "validator");
    rows.push({ name: c.name, kind: c.kind, input: `${c.name}.spec.json`, expected: `${c.name}.expected.json`, ...idx });
  }
  writeIndex("validator", rows);
}

// ---- shared context for actions / expressions / visibility / validation ----------------------
const testFunctions = {
  fullName: (args) => `${args.first} ${args.last}`,
  timestamp: () => 1234567890,
  conditionalSum: (args) => (args.enabled ? args.x + args.y : 0),
};
const directives = core.createDirectiveRegistry([
  core.defineDirective({ name: "$double", schema: z.object({ $double: z.unknown() }),
    resolve: (v, ctx) => core.resolvePropValue(v.$double, ctx) * 2 }),
  core.defineDirective({ name: "$upper", schema: z.object({ $upper: z.unknown() }),
    resolve: (v, ctx) => String(core.resolvePropValue(v.$upper, ctx)).toUpperCase() }),
]);
const scope = (c) => ({
  ...(c.repeatItem !== undefined ? { repeatItem: c.repeatItem } : {}),
  ...(c.repeatIndex !== undefined ? { repeatIndex: c.repeatIndex } : {}),
  ...(c.repeatBasePath !== undefined ? { repeatBasePath: c.repeatBasePath } : {}),
});
function propCtx(c) {
  const ctx = { stateModel: structuredClone(c.state ?? {}), ...scope(c) };
  if (c.functions) ctx.functions = Object.fromEntries(c.functions.map((n) => [n, testFunctions[n]]));
  if (c.directives) ctx.directives = directives;
  return ctx;
}

// ---- actions -------------------------------------------------------------------------------
{
  const { actions } = await caseModule("actions");
  const rows = [];
  for (const c of actions) {
    let file;
    if (c.kind === "interpolate") {
      for (const k of c.cases) expectEqual(`actions/${c.name}`, core.interpolateString(k.input, k.state), k.expected);
      file = { kind: "interpolate", cases: c.cases };
    } else if (c.kind === "resolve") {
      const r = core.resolveAction(structuredClone(c.binding), structuredClone(c.state));
      file = { kind: "resolve", state: c.state, binding: c.binding, expectedResolved: r };
    } else if (c.kind === "param") {
      expectEqual(`actions/${c.name}`, core.resolveActionParam(decode(c.input), propCtx(c)), c.expected);
      file = { kind: "param", state: c.state, ...scope(c), input: c.input, expected: c.expected };
    } else if (c.kind === "execute") {
      const log = [];
      const hooks = { setState: (...a) => log.push({ fn: "setState", args: a }) };
      if (c.hooks.includes("navigate")) hooks.navigate = (...a) => log.push({ fn: "navigate", args: a });
      if (c.hooks.includes("executeAction")) hooks.executeAction = (...a) => log.push({ fn: "executeAction", args: a });
      const handler = async (...a) => {
        log.push({ fn: "handler", args: a });
        if (c.handler === "rejects") throw new Error(c.errorMessage);
      };
      let thrown = null;
      try { await core.executeAction({ action: structuredClone(c.action), handler, ...hooks }); } catch (e) { thrown = e.message; }
      if ((c.expectThrows ?? null) !== thrown) throw new Error(`actions/${c.name}: thrown ${thrown}`);
      expectEqual(`actions/${c.name} calls`, log, c.expectedCalls);
      file = { kind: "execute", action: c.action, handler: c.handler, ...(c.errorMessage ? { errorMessage: c.errorMessage } : {}),
        hooks: c.hooks, expectedCalls: c.expectedCalls, ...(c.expectThrows ? { expectThrows: c.expectThrows } : {}) };
    } else throw new Error(`unknown action kind ${c.kind}`);
    const f = `${c.name}.json`;
    const idx = emit("actions", c.name, { [f]: file }, c.src, "actions");
    rows.push({ name: c.name, kind: c.kind, file: f, ...idx });
  }
  writeIndex("actions", rows);
}

// ---- expressions ---------------------------------------------------------------------------
{
  const { expressions } = await caseModule("expressions");
  const rows = [];
  for (const c of expressions) {
    const ctx = propCtx(c.ctx);
    const input = decode(structuredClone(c.input));
    const real = c.kind === "bindings" ? core.resolveBindings(input, ctx)
      : c.kind === "props" ? core.resolveElementProps(input, ctx)
      : core.resolvePropValue(input, ctx);
    expectEqual(`expressions/${c.name}`, real, c.expected);
    const file = {
      kind: c.kind, state: c.ctx.state ?? {}, ...scope(c.ctx),
      ...(c.ctx.functions ? { functions: c.ctx.functions } : {}),
      ...(c.ctx.directives ? { directives: c.ctx.directives } : {}),
      input: c.input,
      ...(c.kind === "bindings" ? { expectedBindings: c.expected } : { expected: c.expected }),
    };
    const f = `${c.name}.json`;
    const idx = emit("expressions", c.name, { [f]: file }, c.src, "expressions");
    rows.push({ name: c.name, kind: c.kind, file: f, ...idx });
  }
  writeIndex("expressions", rows);
}

// ---- visibility ----------------------------------------------------------------------------
{
  const { visibility } = await caseModule("visibility");
  const rows = [];
  for (const c of visibility) {
    const cond = decode(structuredClone(c.condition));
    const real = c.kind === "split" ? core.splitRepeatVisibility(cond)
      : core.evaluateVisibility(cond, { stateModel: structuredClone(c.state), ...scope(c) });
    expectEqual(`visibility/${c.name}`, real, c.expected);
    const file = { kind: c.kind, ...(c.kind === "evaluate" ? { state: c.state, ...scope(c) } : {}), condition: c.condition, expected: c.expected };
    const f = `${c.name}.json`;
    const idx = emit("visibility", c.name, { [f]: file }, c.src, "visibility");
    rows.push({ name: c.name, kind: c.kind, file: f, ...idx });
  }
  writeIndex("visibility", rows);
}

// ---- validation ----------------------------------------------------------------------------
{
  const { validation } = await caseModule("validation");
  const customFns = { startsWithA: (v) => typeof v === "string" && v.startsWith("A") };
  const rows = [];
  for (const c of validation) {
    let file;
    if (c.kind === "run") {
      const r = core.runValidation(decode(structuredClone(c.config)), {
        value: decode(c.value), stateModel: structuredClone(c.state),
        ...(c.customFunctions ? { customFunctions: Object.fromEntries(c.customFunctions.map((n) => [n, customFns[n]])) } : {}),
      });
      expectEqual(`validation/${c.name} valid`, r.valid, c.expected.valid);
      expectEqual(`validation/${c.name} errors`, r.errors, c.expected.errors);
      if (c.expected.checkCount !== undefined) expectEqual(`validation/${c.name} checkCount`, r.checks.length, c.expected.checkCount);
      if (c.expected.checks) {
        expectEqual(`validation/${c.name} checks`, r.checks.map((k) => ({ type: k.type, valid: k.valid, message: k.message })), c.expected.checks);
      }
      file = { kind: "run", state: c.state, value: c.value, ...(c.customFunctions ? { customFunctions: c.customFunctions } : {}),
        config: c.config, expected: c.expected };
    } else {
      const real = core.check[c.fn](...c.args);
      for (const [k, v] of Object.entries(c.expected)) expectEqual(`validation/${c.name} ${k}`, real[k], v);
      const partial = Object.keys(real).some((k) => !(k in c.expected));
      file = { kind: "helper", fn: c.fn, args: c.args, expected: c.expected, ...(partial ? { partial: true } : {}) };
    }
    const f = `${c.name}.json`;
    const idx = emit("validation", c.name, { [f]: file }, c.src, "validation");
    rows.push({ name: c.name, kind: c.kind, file: f, ...idx });
  }
  writeIndex("validation", rows);
}

stage.flushEntries(".entries-cases.json");
const counts = {};
for (const k of names) counts[k.split("/")[0]] = (counts[k.split("/")[0]] ?? 0) + 1;
console.log("cases:", JSON.stringify(counts));
