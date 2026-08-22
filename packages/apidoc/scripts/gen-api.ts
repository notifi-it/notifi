import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { bruno, openapi, postman } from '../src/index.js';

const here = dirname(fileURLToPath(import.meta.url));
const PUBLIC = join(here, '..', '..', '..', 'apps', 'api', 'public');

const artifacts: Array<[string, string]> = [
  ['openapi.json', `${JSON.stringify(openapi(), null, 2)}\n`],
  ['notifi.postman_collection.json', `${JSON.stringify(postman(), null, 2)}\n`],
  ['notifi.bru', bruno()],
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
