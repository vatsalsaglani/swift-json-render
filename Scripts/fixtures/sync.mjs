// usage: node sync.mjs <stage> <out>
// Copies staged files into <out>. A file is written only when its sha256 differs (temp file + rename).
// Files in <out> that are not staged are removed. Prints a one-line summary.
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [stageDir, outDir] = process.argv.slice(2);
const walk = (d, base = d) =>
  fs.existsSync(d)
    ? fs.readdirSync(d, { withFileTypes: true }).flatMap((e) =>
        e.isDirectory() ? walk(path.join(d, e.name), base) : [path.relative(base, path.join(d, e.name))])
    : [];
const sha = (p) => crypto.createHash("sha256").update(fs.readFileSync(p)).digest("hex");
const staged = walk(stageDir).filter((f) => !path.basename(f).startsWith("."));
let written = 0, unchanged = 0, removed = 0, bytes = 0;
for (const rel of staged) {
  const src = path.join(stageDir, rel);
  const dst = path.join(outDir, rel);
  bytes += fs.statSync(src).size;
  if (fs.existsSync(dst) && sha(dst) === sha(src)) { unchanged++; continue; }
  fs.mkdirSync(path.dirname(dst), { recursive: true });
  const tmp = `${dst}.tmp-${process.pid}`;
  fs.copyFileSync(src, tmp);
  fs.renameSync(tmp, dst);
  written++;
}
const keep = new Set(staged);
for (const rel of walk(outDir)) {
  if (!keep.has(rel)) { fs.rmSync(path.join(outDir, rel)); removed++; }
}
console.log(`fixtures: written=${written} unchanged=${unchanged} removed=${removed} bytes=${bytes}`);
