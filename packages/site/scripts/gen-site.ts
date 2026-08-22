import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  docsBody,
  docsStyle,
  landingEndpoint,
  landingNote,
  landingPanels,
  landingRows,
  landingTabs,
} from '@notifi/apidoc';
import { document, footer } from '../src/chrome.js';
import type { Meta, Page } from '../src/chrome.js';
import { APP_STORE, MAC_DOWNLOAD, ORIGIN } from '../src/constants.js';
import { front, main } from '../src/markdown.js';
import { ORG_ID, graph, pageNode } from '../src/schema.js';

const here = dirname(fileURLToPath(import.meta.url));
const ROOT = join(here, '..');
const PUBLIC = join(ROOT, '..', '..', 'apps', 'api', 'public');

const read = (...parts: string[]) => readFileSync(join(ROOT, ...parts), 'utf8');

const tokens = read('src', 'tokens.css');
const terminalCss = read('src', 'terminal.css');
const terminalJs = read('src', 'terminal.js');
const pageMdJs = read('src', 'pagemd.js');
const site = read('src', 'site.js');

const PROSE = ['about', 'contact', 'faq', 'terms', 'privacy'];

function prose(name: string): Page {
  const parsed = front(read('pages', `${name}.md`));
  const f = parsed.front;
  const need = (key: string): string => {
    const value = f[key];
    if (value === undefined) throw new Error(`${name}.md has no ${key}`);
    return value;
  };
  const path = need('path');
  const meta: Meta = {
    path,
    title: need('title'),
    description: need('description'),
    ogTitle: need('ogTitle'),
    ogDescription: need('ogDescription'),
  };
  if (f['schemaType']) {
    meta.schema = graph([
      pageNode(f['schemaType'], path, need('schemaName'), need('schemaDescription')),
    ]);
  }
  const page: Page = { meta, body: main(f['eyebrow'] ?? '', parsed.body) };
  const style = f['style'];
  if (style) page.style = read('pages', style);
  return page;
}

function docs(): Page {
  return {
    meta: {
      path: '/docs',
      title: 'notifi API documentation: one endpoint, seven parameters',
      description:
        'The notifi API reference: authenticate with a send key, POST a title and a body to /send, and read the response. Parameters, error codes, limits, and the machine-readable descriptions.',
      ogTitle: 'notifi API documentation',
      ogDescription:
        'One endpoint and seven parameters. Authentication, parameters, responses, error codes and limits.',
      schema: graph([
        pageNode(
          'TechArticle',
          '/docs',
          'notifi API documentation',
          'The notifi API reference: the /send endpoint, its parameters, its responses and its limits.',
          { headline: 'notifi API documentation', proficiencyLevel: 'Beginner' },
        ),
      ]),
    },
    body: docsBody(),
    style: `${docsStyle()}\n${terminalCss}`,
    script: `${terminalJs}\n${pageMdJs}`,
  };
}

function notFound(): Page {
  return {
    meta: {
      path: '/404',
      title: 'notifi: page not found',
      description:
        'That address does not exist on notifi.it. Here is everything the site does have: the API documentation, the FAQ, llms.txt and the OpenAPI description.',
      ogTitle: 'notifi: page not found',
      ogDescription: 'That address does not exist. Here is everything notifi.it does have.',
      noindex: true,
    },
    body: read('pages', '404.html').trimEnd(),
    style: read('pages', '404.css'),
    script: read('pages', '404.js'),
    reveal: false,
  };
}

const LANDING_NODES: Array<Record<string, unknown>> = [
  {
    '@type': 'WebSite',
    '@id': `${ORIGIN}/#website`,
    url: `${ORIGIN}/`,
    name: 'notifi',
    description:
      'Push notifications to your iPhone or Mac from one plain HTTP request. No account, no SDK, encrypted with your public key, and open source.',
    publisher: { '@id': ORG_ID },
    inLanguage: 'en',
  },
  {
    '@type': 'SoftwareApplication',
    '@id': `${ORIGIN}/#app`,
    name: 'notifi',
    url: `${ORIGIN}/`,
    applicationCategory: 'DeveloperApplication',
    operatingSystem: 'iOS 17.0 or later, macOS 14.0 or later',
    installUrl: APP_STORE,
    downloadUrl: `${ORIGIN}${MAC_DOWNLOAD}`,
    description:
      'The app makes you a send key on first launch. Copy it, then make one HTTP request to notifi.it from any script, and a native push notification arrives on your iPhone or Mac. Notification content is encrypted with your public key. No SDK, no account, no sign-in.',
    featureList: [
      'One plain HTTP request, GET or POST, JSON or form-encoded',
      'No SDK, no account and no sign-in',
      'Notification content encrypted with your public key',
      'Open source',
      'Per-script revocable send keys',
      'Title, body, link and image parameters',
      'Searchable notification history',
    ],
    publisher: { '@id': ORG_ID },
    offers: { '@type': 'Offer', price: 0, priceCurrency: 'GBP' },
  },
];

function splice(html: string, marker: string, body: string, comment = 'html'): string {
  const wrap = (text: string) =>
    comment === 'html' ? `<!-- ${text} -->` : comment === 'css' ? `/* ${text} */` : `// ${text}`;
  const open = wrap(`gen:${marker}`);
  const close = wrap(`/gen:${marker}`);
  const start = html.indexOf(open);
  const end = html.indexOf(close);
  if (start === -1 || end === -1) throw new Error(`index.html has no ${marker} markers`);
  return `${html.slice(0, start + open.length)}\n${body}\n${html.slice(end)}`;
}

function landing(): string {
  let html = readFileSync(join(PUBLIC, 'index.html'), 'utf8');
  html = splice(html, 'schema', graph(LANDING_NODES));
  html = splice(html, 'footer', footer({ path: '/' } as Meta));
  html = splice(html, 'endpoint', landingEndpoint());
  html = splice(html, 'params', landingRows());
  html = splice(html, 'apinote', landingNote());
  html = splice(html, 'tabs', landingTabs());
  html = splice(html, 'panels', landingPanels());
  html = splice(html, 'termcss', terminalCss.trimEnd(), 'css');
  html = splice(html, 'termjs', terminalJs.trimEnd(), 'js');
  return html;
}

const pages: Array<[string, Page]> = [
  ...PROSE.map((name): [string, Page] => [`${name}.html`, prose(name)]),
  ['docs.html', docs()],
  ['404.html', notFound()],
];

const check = process.argv.includes('--check');
let drift = 0;
let written = 0;

const artifacts: Array<[string, string]> = [
  ...pages.map(([name, page]): [string, string] => [name, document(page, tokens, site)]),
  ['index.html', landing()],
];

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
  console.error(`\n${drift} page(s) out of date. Run \`make gen-site\` and commit.`);
  process.exit(1);
}
if (check) console.log('site pages are up to date');
else if (written === 0) console.log('site pages already up to date');
