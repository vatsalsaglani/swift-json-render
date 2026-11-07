// Copies data/components.json into data/components.js so the pages also work from file://
// (browsers block fetch() of local files). components.json stays the single source.
// Run: node site/tools/sync-data.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const dir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..', 'data');
const json = fs.readFileSync(path.join(dir, 'components.json'), 'utf8');
const doc = JSON.parse(json);
const js = '/* Generated from components.json by tools/sync-data.mjs. Do not edit. */\n' +
  '(function (g) { (g.JR = g.JR || {}).registry = ' + JSON.stringify(doc) + '; })(typeof globalThis !== "undefined" ? globalThis : this);\n';
fs.writeFileSync(path.join(dir, 'components.js'), js);
console.log('wrote data/components.js (' + js.length + ' bytes, ' + doc.components.length + ' components)');
