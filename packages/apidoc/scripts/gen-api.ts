import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  bruno,
  docsBody,
  docsStyle,
  landingEndpoint,
  landingNote,
  landingPanels,
  landingRows,
  landingTabs,
  openapi,
  postman,
} from '../src/index.js';

const here = dirname(fileURLToPath(import.meta.url));
const PUBLIC = join(here, '..', '..', '..', 'apps', 'api', 'public');
const TEMPLATE = join(here, '..', 'templates', 'docs.html');

function splice(html: string, marker: string, body: string): string {
  const open = `<!-- gen:${marker} -->`;
  const close = `<!-- /gen:${marker} -->`;
  const start = html.indexOf(open);
  const end = html.indexOf(close);
  if (start === -1 || end === -1) throw new Error(`index.html has no ${marker} markers`);
  return `${html.slice(0, start + open.length)}\n${body}\n${html.slice(end)}`;
}

function docsHtml(): string {
  return readFileSync(TEMPLATE, 'utf8')
    .replace('{{STYLE}}', docsStyle())
    .replace('{{BODY}}', docsBody());
}

function landingHtml(): string {
  let html = readFileSync(join(PUBLIC, 'index.html'), 'utf8');
  html = splice(html, 'endpoint', landingEndpoint());
  html = splice(html, 'params', landingRows());
  html = splice(html, 'apinote', landingNote());
  html = splice(html, 'tabs', landingTabs());
  html = splice(html, 'panels', landingPanels());
  return html;
}

const artifacts: Array<[string, string]> = [
  ['docs.html', docsHtml()],
  ['openapi.json', `${JSON.stringify(openapi(), null, 2)}\n`],
  ['notifi.postman_collection.json', `${JSON.stringify(postman(), null, 2)}\n`],
  ['notifi.bru', bruno()],
  ['index.html', landingHtml()],
];

const check = process.argv.includes('--check');
let drift = 0;
let written = 0;

for (const [name, body] of artifacts) {
  const target = join(PUBLIC, name);
  let current: string | null = null;
  try {
    current = readFileSync(target, 'utf8');
  } catch {
    current = null;
  }
  if (current === body) continue;
  if (check) {
    console.error(`${name} is out of date`);
    drift++;
  } else {
    writeFileSync(target, body);
    written++;
    console.log(`wrote ${name}`);
  }
}

if (check && drift > 0) {
  console.error(`\n${drift} generated file(s) out of date. Run \`make gen-api\` and commit.`);
  process.exit(1);
}
if (check) console.log('generated API files are up to date');
else if (written === 0) console.log('generated API files already up to date');
