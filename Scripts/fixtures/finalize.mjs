// usage: node finalize.mjs <stage> <clone> <commit>
// Copies the upstream LICENSE and writes MANIFEST.json (sha256 for every staged file).
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";

const [stageDir, clone, commit] = process.argv.slice(2);
fs.copyFileSync(path.join(clone, "LICENSE"), path.join(stageDir, "LICENSE-json-render"));
const entries = fs
  .readdirSync(stageDir)
  .filter((f) => f.startsWith(".entries-") && f.endsWith(".json"))
  .sort()
  .flatMap((f) => JSON.parse(fs.readFileSync(path.join(stageDir, f), "utf8")));
entries.push({
  path: "LICENSE-json-render",
  kind: "license",
  upstreamPath: "LICENSE",
  upstreamLines: "1-" + fs.readFileSync(path.join(clone, "LICENSE"), "utf8").split("\n").length,
});

const files = entries
  .map((e) => {
    const data = fs.readFileSync(path.join(stageDir, e.path));
    return {
      path: e.path,
      kind: e.kind,
      upstreamPath: e.upstreamPath,
      upstreamLines: e.upstreamLines,
      commit,
      sha256: crypto.createHash("sha256").update(data).digest("hex"),
      bytes: data.length,
      licence: "Apache-2.0",
    };
  })
  .sort((a, b) => (a.path < b.path ? -1 : 1));
const seen = new Set();
for (const f of files) {
  if (seen.has(f.path)) throw new Error(`duplicate manifest path ${f.path}`);
  seen.add(f.path);
}
const generatedWith = JSON.parse(fs.readFileSync(path.join(stageDir, ".generated-with.json"), "utf8"));
const manifest = {
  schema: 1,
  upstream: {
    repository: "https://github.com/vercel-labs/json-render",
    commit,
    release: "v0.22.0",
    licence: "Apache-2.0",
    copyright: "Copyright 2025 Vercel Inc.",
  },
  generatedWith,
  note: "Files are read-only after wave 0. sha256 covers the file bytes. upstreamLines is the line range of the source test block; generated files have no source lines.",
  files,
};
fs.writeFileSync(path.join(stageDir, "MANIFEST.json"), JSON.stringify(manifest, null, 2) + "\n");
console.log(`manifest: ${files.length} files`);
