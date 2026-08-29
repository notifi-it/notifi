import { EMAIL, GITHUB, ORIGIN, OG_IMAGE, OG_IMAGE_ALT, SOCIAL, THEME_COLOR } from './constants.js';

export interface Link {
  href: string;
  label: string;
  rel?: string;
}

export const NAV: Link[] = [
  { href: '/', label: 'Home' },
  { href: '/#api', label: 'API' },
  { href: '/#download', label: 'Download' },
  { href: '/faq', label: 'FAQ' },
];

export const FOOTER: Link[] = [
  { href: '/', label: 'Home' },
  { href: '/docs', label: 'Docs' },
  { href: '/faq', label: 'FAQ' },
  { href: '/privacy', label: 'Privacy' },
  { href: '/terms', label: 'Terms' },
  { href: '/llms.txt', label: 'llms.txt' },
  { href: `mailto:${EMAIL}`, label: EMAIL },
  { href: GITHUB, label: 'GitHub' },
  ...SOCIAL.map((s) => ({ href: s.url, label: s.name, rel: 'me' })),
];

export interface Meta {
  path: string;
  title: string;
  description: string;
  ogTitle: string;
  ogDescription: string;
  noindex?: boolean;
  markdown?: boolean;
  schema?: string;
  nav?: Link[];
  fontNote?: string;
}

const FONT_NOTE = `Self-hosted, so the page has no third-party request at all. Latin
     subset only.`;

function tag(link: Link): string {
  const rel = link.rel ? ` rel="${link.rel}"` : '';
  return `<a href="${link.href}"${rel}>${link.label}</a>`;
}

function withoutSelf(links: Link[], path: string): Link[] {
  return links.filter((link) => link.href !== path);
}

export function head(meta: Meta, style: string): string {
  const url = `${ORIGIN}${meta.path}`;
  const markdown = meta.markdown === false ? '' : `
<!-- The same page as Markdown. The Worker also answers this URL with it
     when a request asks for \`Accept: text/markdown\`, so an agent gets the
     prose without the markup from whichever address it already had. -->
<link rel="alternate" type="text/markdown" href="${meta.path === '/' ? '/index.md' : `${meta.path}.md`}" title="This page as Markdown">
`;
  const robots = meta.noindex ? '\n<meta name="robots" content="noindex">\n' : '';
  const schema = meta.schema ? `\n${meta.schema}\n` : '';
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${meta.title}</title>
<meta name="description" content="${meta.description}">
<meta name="theme-color" content="${THEME_COLOR}">
<link rel="icon" href="/favicon.svg" type="image/svg+xml">
<link rel="apple-touch-icon" href="/apple-touch-icon.png">

<!-- The assets binding 307s the .html form of this path to the extensionless
     one, so both are reachable. Pin the one that should be indexed. -->
<link rel="canonical" href="${url}">
${markdown}
<meta property="og:title" content="${meta.ogTitle}">
<meta property="og:description" content="${meta.ogDescription}">
<meta property="og:type" content="website">
<meta property="og:url" content="${url}">
<meta property="og:site_name" content="notifi">
<meta property="og:locale" content="en_GB">
<meta property="og:image" content="${OG_IMAGE}">
<meta property="og:image:width" content="2400">
<meta property="og:image:height" content="1260">
<meta property="og:image:alt" content="${OG_IMAGE_ALT}">

<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${meta.ogTitle}">
<meta name="twitter:description" content="${meta.ogDescription}">
<meta name="twitter:image" content="${OG_IMAGE}">
<meta name="twitter:image:alt" content="${OG_IMAGE_ALT}">
${schema}${robots}
<!-- ${meta.fontNote ?? FONT_NOTE} -->
<link rel="preload" href="/fonts/recursive-mono.woff2" as="font" type="font/woff2" crossorigin>

<style>${style}</style>
</head>`;
}

export function header(meta: Meta): string {
  const links = withoutSelf(meta.nav ?? NAV, meta.path);
  return `<header>
  <div class="wrap bar">
    <a class="mark lockup" href="/" aria-label="notifi" style="--bell:24px;--word:19px;--lockgap:10px">
      <span class="bell" aria-hidden="true"></span>
      <img src="/wordmark.svg" alt="notifi">
    </a>
    <nav>
${links.map((link) => `      ${tag(link)}`).join('\n')}
    </nav>
  </div>
</header>`;
}

export function footer(meta: Meta): string {
  const links = withoutSelf(FOOTER, meta.path);
  return `<footer>
  <div class="wrap">
    <div class="lockup" style="--bell:44px;--word:36px;--lockgap:16px;margin-bottom:26px">
      <span class="bell" aria-hidden="true"></span>
      <img src="/wordmark.svg" alt="notifi">
    </div>
  </div>
  <!-- The sticky header already carries the navigation, so the footer holds
       only what is not up there — and never a link to the page you are on. -->
  <div class="wrap foot">
${links.map((link) => `    ${tag(link)}`).join('\n')}
  </div>
</footer>`;
}

export interface Page {
  meta: Meta;
  body: string;
  style?: string;
  script?: string;
  reveal?: boolean;
}

export function document(page: Page, tokens: string, site: string): string {
  const style = page.style ? `${tokens}${page.style}` : tokens;
  const bodyAttrs: string[] = [];
  if (page.meta.path === '/404') bodyAttrs.push('class="notfound"');
  if (page.reveal === false) bodyAttrs.push('data-reveal="off"');
  const attrs = bodyAttrs.length ? ` ${bodyAttrs.join(' ')}` : '';
  const extra = page.script ? `\n<script>${page.script}</script>` : '';
  return `${head(page.meta, style)}
<body${attrs}>
<canvas id="static" aria-hidden="true"></canvas>

${header(page.meta)}

${page.body}

${footer(page.meta)}

<script>
${site}</script>${extra}
</body>
</html>
`;
}
