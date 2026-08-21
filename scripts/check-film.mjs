import { execFileSync } from 'node:child_process';
import { readFileSync, writeFileSync } from 'node:fs';

const INDEX = 'apps/api/public/index.html';
const BUILD = 'sketches/gif/build.py';

const committed = readFileSync(INDEX, 'utf8');

let regenerated;
try {
  execFileSync('python3', ['build.py'], { cwd: 'sketches/gif', stdio: 'pipe' });
  regenerated = readFileSync(INDEX, 'utf8');
} finally {
  writeFileSync(INDEX, committed);
}

if (regenerated !== committed) {
  console.error(
    `Film check failed:\n\n  ${INDEX} does not match what ${BUILD} generates.\n\n` +
      '  The scene between the gf: markers is generated from sketches/gif/gen.py and must\n' +
      '  never be edited in place. Describe the change in gen.py, then run `make film`.\n',
  );
  process.exit(1);
}
