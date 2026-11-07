// usage: node check.mjs <out> [<clone>]
// Offline shape and size checks. Exit 1 on any failure. With <clone>, also compares the licence.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [out, clone] = process.argv.slice(2);
const KiB = 1024;
const errors = [];
const fail = (m) => errors.push(m);
const walk = (d, base = d) =>
  fs.readdirSync(d, { withFileTypes: true }).flatMap((e) =>
    e.isDirectory() ? walk(path.join(d, e.name), base) : [path.relative(base, path.join(d, e.name))]);

const manifestPath = path.join(out, "MANIFEST.json");
if (!fs.existsSync(manifestPath)) { console.error("check: MANIFEST.json missing"); process.exit(1); }
const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
const listed = new Set(manifest.files.map((f) => f.path));
const onDisk = walk(out).filter((f) => f !== "MANIFEST.json");
for (const f of onDisk) if (!listed.has(f)) fail(`not in manifest: ${f}`);

let total = fs.statSync(manifestPath).size;
const schemaExempt = new Set(["schema/shadcn.strict.json", "schema/shadcn.loose.json"]);
const sizes = {};
for (const f of manifest.files) {
  const p = path.join(out, f.path);
  if (!fs.existsSync(p)) { fail(`missing: ${f.path}`); continue; }
  const data = fs.readFileSync(p);
  total += data.length;
  const sha = crypto.createHash("sha256").update(data).digest("hex");
  if (sha !== f.sha256) fail(`sha256 drift: ${f.path}`);
  if (f.commit !== manifest.upstream.commit) fail(`commit mismatch: ${f.path}`);
  if (schemaExempt.has(f.path)) {
    sizes[f.path] = data.length;
    if (data.length >= 1024 * KiB) fail(`schema too large: ${f.path}`);
  } else if (data.length > 256 * KiB) fail(`file over 256 KiB: ${f.path}`);
  if (f.path.endsWith(".json")) {
    try { JSON.parse(data.toString("utf8")); } catch (e) { fail(`invalid JSON ${f.path}: ${e.message}`); }
  }
  if (f.path.endsWith(".jsonl") && data.toString("utf8").split("\n").filter((l) => l.length).length < 1) fail(`empty jsonl: ${f.path}`);
}
if (total > 1.5 * 1024 * KiB) fail(`total ${total} bytes over 1.5 MiB`);

// example specs: root exists; every child and slot id exists
const idxPath = path.join(out, "specs/index.json");
if (fs.existsSync(idxPath)) {
  const idx = JSON.parse(fs.readFileSync(idxPath, "utf8"));
  if (idx.length !== 8) fail(`specs/index.json lists ${idx.length}, expected 8`);
  for (const row of idx) {
    const spec = JSON.parse(fs.readFileSync(path.join(out, "specs", row.file), "utf8"));
    if (!(spec.root in spec.elements)) fail(`${row.file}: root not in elements`);
    for (const [id, el] of Object.entries(spec.elements)) {
      const refs = [...(el.children ?? []), ...Object.values(el.slots ?? {}).flat()];
      for (const r of refs) if (!(r in spec.elements)) fail(`${row.file}: ${id} references missing ${r}`);
    }
  }
} else fail("specs/index.json missing");

if (clone) {
  const a = fs.readFileSync(path.join(clone, "LICENSE"));
  const b = fs.readFileSync(path.join(out, "LICENSE-json-render"));
  if (!a.equals(b)) fail("LICENSE-json-render differs from the clone LICENSE");
}

if (errors.length) {
  for (const e of errors) console.error("check: " + e);
  process.exit(1);
}
console.log(`check: ok (${manifest.files.length} files, ${total} bytes; shadcn strict=${sizes["schema/shadcn.strict.json"]} loose=${sizes["schema/shadcn.loose.json"]})`);
