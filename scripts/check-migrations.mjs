import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const MIGRATIONS = 'apps/api/migrations';
const SCHEMA = 'apps/api/prisma/schema.prisma';

const problems = [];

const files = readdirSync(MIGRATIONS).filter((f) => f.endsWith('.sql')).sort();

for (const [i, file] of files.entries()) {
  const expected = String(i + 1).padStart(4, '0');
  if (!file.startsWith(`${expected}_`)) {
    problems.push(`${MIGRATIONS}/${file}: expected the sequence to reach ${expected} here`);
  }
  const sql = readFileSync(join(MIGRATIONS, file), 'utf8');
  if (/\bDROP TABLE\b/i.test(sql) || /PRAGMA\s+(defer_)?foreign_keys/i.test(sql)) {
    problems.push(
      `${MIGRATIONS}/${file}: rebuilds a table (DROP TABLE / PRAGMA foreign_keys). ` +
        'D1 has no down migrations, so this destroys live rows.',
    );
  }
}

const PRISMA = 'apps/api/node_modules/.bin/prisma';
if (!existsSync(PRISMA)) {
  problems.push(`${PRISMA} is missing. Run \`pnpm install\` before this check.`);
} else {
  try {
    execFileSync(PRISMA, ['validate', '--schema', SCHEMA], { stdio: 'pipe' });
  } catch (err) {
    problems.push(`${SCHEMA} is not valid:\n${err.stdout ?? ''}${err.stderr ?? ''}`);
  }
}

const base = process.env.GITHUB_BASE_REF;
if (base) {
  let changed;
  try {
    changed = execFileSync('git', ['diff', '--name-only', `origin/${base}...HEAD`], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'pipe'],
    })
      .split('\n')
      .filter(Boolean);
  } catch {
    console.error(
      `Could not diff against origin/${base}. The checkout needs full history ` +
        '(actions/checkout with fetch-depth: 0) for this check to run.',
    );
    process.exit(1);
  }

  const touchedMigrations = changed.filter((f) => f.startsWith(`${MIGRATIONS}/`));
  if (touchedMigrations.length > 0 && !changed.includes(SCHEMA)) {
    problems.push(
      `${touchedMigrations.join(', ')} changed but ${SCHEMA} did not.\n` +
        '  A migration is generated from the schema, never typed by hand: describe the change ' +
        `in ${SCHEMA}, then run \`make migration name=<snake_case>\`.`,
    );
  }
}

if (problems.length > 0) {
  console.error(`Migration check failed:\n\n${problems.map((p) => `  - ${p}`).join('\n\n')}\n`);
  process.exit(1);
}
