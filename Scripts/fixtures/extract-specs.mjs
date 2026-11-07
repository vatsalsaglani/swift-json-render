// usage: node extract-specs.mjs <clone> <stage> <npmDir>
// Extracts the eight example specs from examples/no-ai/lib/examples.ts by transpiling the
// pinned upstream file with TypeScript (no eval of data, no regex surgery).
import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import { createRequire } from "node:module";
import { pathToFileURL } from "node:url";
import { createStage, kebab } from "./lib.mjs";

const [clone, stageDir, npmDir] = process.argv.slice(2);
const require = createRequire(path.join(npmDir, "noop.js"));
const ts = require("typescript");
const rel = "examples/no-ai/lib/examples.ts";
const source = fs.readFileSync(path.join(clone, rel), "utf8");
const out = ts.transpileModule(source, {
  compilerOptions: { module: ts.ModuleKind.ESNext, target: ts.ScriptTarget.ES2022 },
});
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "jr-examples-"));
const file = path.join(tmp, "examples.mjs");
fs.writeFileSync(file, out.outputText);
const { examples } = await import(pathToFileURL(file).href);
fs.rmSync(tmp, { recursive: true, force: true });

const stage = createStage(stageDir, clone);
const srcLines = source.split("\n");
const index = [];
examples.forEach((ex, i) => {
  const start = srcLines.findIndex((l) => l === `    name: ${JSON.stringify(ex.name)},`) + 1;
  const next = i + 1 < examples.length
    ? srcLines.findIndex((l) => l === `    name: ${JSON.stringify(examples[i + 1].name)},`) + 1 - 2
    : srcLines.findIndex((l) => l === "];");
  const file = `${kebab(ex.name)}.json`;
  stage.writeJSON(`specs/${file}`, ex.spec, {
    kind: "spec",
    upstreamPath: rel,
    upstreamLines: `${start - 1}-${next}`,
  });
  index.push({ name: ex.name, description: ex.description, file });
});
stage.writeJSON("specs/index.json", index, { kind: "index", upstreamPath: rel, upstreamLines: "9-" + srcLines.length });
stage.flushEntries(".entries-specs.json");
console.log(`specs: ${examples.length}`);
