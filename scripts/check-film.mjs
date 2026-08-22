import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

const INDEX = 'apps/api/public/index.html';
const BUILD = 'sketches/gif/build.py';

const committed = readFileSync(INDEX, 'utf8');

let regenerated;
let failure = null;
try {
  execFileSync('python3', ['build.py'], { cwd: 'sketches/gif', stdio: 'pipe' });
  regenerated = readFileSync(INDEX, 'utf8');
} catch (err) {
  failure = err;
} finally {
  writeFileSync(INDEX, committed);
}

if (failure) {
  process.stderr.write(failure.stderr?.toString() || `${failure.message}\n`);
  process.exit(1);
}

if (regenerated !== committed) {
  console.error(
    `Film check failed:\n\n  ${INDEX} does not match what ${BUILD} generates.\n\n` +
      '  The scene between the gf: markers is generated from sketches/gif/gen.py and must\n' +
      '  never be edited in place. Describe the change in gen.py, then run `make film`.\n',
  );
  process.exit(1);
}
