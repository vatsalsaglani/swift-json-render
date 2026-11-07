// Shared helpers for the fixture importer. Node only; no network; no eval.
import fs from "node:fs";
import path from "node:path";

/** Stage a file and record its provenance. Content is a string. */
export function createStage(stageDir, cloneDir) {
  const entries = [];
  const lineCache = new Map();
  const lines = (rel) => {
    if (!lineCache.has(rel)) {
      lineCache.set(rel, fs.readFileSync(path.join(cloneDir, rel), "utf8").split("\n"));
    }
    return lineCache.get(rel);
  };
  return {
    stageDir,
    lines,
    entries,
    write(rel, content, meta) {
      const full = path.join(stageDir, rel);
      fs.mkdirSync(path.dirname(full), { recursive: true });
      fs.writeFileSync(full, content);
      entries.push({ path: rel, ...meta });
    },
    writeJSON(rel, value, meta) {
      this.write(rel, JSON.stringify(value, null, 2) + "\n", meta);
    },
    /** "packages/core/src/x.test.ts:123" -> { upstreamPath, upstreamLines: "123-130" } */
    locate(ref) {
      const i = ref.lastIndexOf(":");
      const rel = ref.slice(0, i);
      const start = Number(ref.slice(i + 1));
      const ls = lines(rel);
      const first = ls[start - 1];
      if (first === undefined) throw new Error(`bad reference ${ref}`);
      const indent = first.match(/^\s*/)[0];
      let end = start;
      for (let n = start; n < ls.length; n++) {
        if (ls[n].startsWith(indent + "});") || ls[n] === indent + "}") {
          end = n + 1;
          break;
        }
      }
      return { upstreamPath: rel, upstreamLines: `${start}-${end}` };
    },
    flushEntries(name = ".entries.json") {
      fs.writeFileSync(path.join(stageDir, name), JSON.stringify(entries, null, 2));
    },
  };
}

/** Deep-equal on JSON-ish values, treating undefined consistently. */
export function jsonEqual(a, b) {
  return JSON.stringify(canon(a)) === JSON.stringify(canon(b));
}
function canon(v) {
  if (Array.isArray(v)) return v.map(canon);
  if (v && typeof v === "object") {
    return Object.fromEntries(
      Object.keys(v)
        .filter((k) => v[k] !== undefined)
        .sort()
        .map((k) => [k, canon(v[k])]),
    );
  }
  if (typeof v === "number" && Number.isNaN(v)) return "$nan";
  return v;
}

/** JSON encoding of values: undefined -> {"$undefined":true}, NaN -> {"$nan":true}. */
export function encode(v) {
  if (v === undefined) return { $undefined: true };
  if (typeof v === "number" && Number.isNaN(v)) return { $nan: true };
  if (Array.isArray(v)) return v.map(encode);
  if (v && typeof v === "object") {
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)]));
  }
  return v;
}
/** Inverse of encode, used when feeding case data to the upstream implementation. */
export function decode(v) {
  if (v && typeof v === "object" && !Array.isArray(v)) {
    const keys = Object.keys(v);
    if (keys.length === 1 && keys[0] === "$undefined") return undefined;
    if (keys.length === 1 && keys[0] === "$nan") return NaN;
    return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, decode(x)]));
  }
  if (Array.isArray(v)) return v.map(decode);
  return v;
}

export function kebab(s) {
  return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
}
