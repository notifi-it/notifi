import { build } from 'esbuild';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

await build({
  entryPoints: [join(here, 'entry.js')],
  outfile: join(here, '..', 'public', 'film.js'),
  bundle: true,
  minify: true,
  format: 'iife',
  target: 'es2020',
  loader: { '.jsx': 'jsx' },
  jsxFactory: 'React.createElement',
  jsxFragment: 'React.Fragment',
  alias: { react: 'preact/compat', 'react-dom': 'preact/compat' },
  legalComments: 'none',
});
