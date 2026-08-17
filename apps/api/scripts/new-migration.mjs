import { execFileSync } from 'node:child_process';
import { mkdtempSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const name = process.argv[2];
if (!name || !/^[a-z0-9]+(_[a-z0-9]+)*$/.test(name)) {
  console.error('usage: node scripts/new-migration.mjs <snake_case_name>');
  process.exit(1);
}

const SCHEMA = 'prisma/schema.prisma';
const MIGRATIONS = 'migrations';

let committed;
try {
  committed = execFileSync('git', ['show', `HEAD:apps/api/${SCHEMA}`], {
    encoding: 'utf8',
    cwd: '../..',
    stdio: ['ignore', 'pipe', 'ignore'],
  });
} catch {
  console.error(
    `${SCHEMA} is not committed at HEAD, so there is nothing to diff against. ` +
      'Commit it unchanged first, then edit it.',
  );
  process.exit(1);
}

const work = mkdtempSync(join(tmpdir(), 'notifi-migration-'));
const before = join(work, 'before.prisma');
writeFileSync(before, committed);

const sql = execFileSync(
  'node_modules/.bin/prisma',
  [
    'migrate',
    'diff',
    '--from-schema-datamodel',
    before,
    '--to-schema-datamodel',
    SCHEMA,
    '--script',
  ],
  { encoding: 'utf8' },
).trim();

if (sql === '' || sql === '-- This is an empty migration.') {
  console.error(`No change between the committed ${SCHEMA} and the working copy.`);
  process.exit(1);
}

if (/DROP TABLE|PRAGMA (defer_)?foreign_keys/.test(sql)) {
  console.error('Refusing to write a migration that rebuilds a table.\n');
  console.error(sql);
  console.error(
    '\nD1 has no down migrations and this destroys and recreates live data. ' +
      'Express the change as an additive column, or write the SQL by hand and say why in the commit.',
  );
  process.exit(1);
}

const last = readdirSync(MIGRATIONS)
  .filter((f) => f.endsWith('.sql'))
  .sort()
  .at(-1);
const next = String(Number(last.slice(0, 4)) + 1).padStart(4, '0');
const file = join(MIGRATIONS, `${next}_${name}.sql`);

writeFileSync(file, `${sql}\n`);
console.log(`${file}\n`);
console.log(readFileSync(file, 'utf8'));
console.log('Add a comment saying why, then run: make migrate');
