import { Hono } from 'hono';
import type { Context } from 'hono';
import { appendVaryAccept, preferredType } from '../lib/accept.js';
import { errBody, t } from '../lib/respond.js';
import type { AppEnv } from '../types.js';

const HTML = 'text/html';
const MARKDOWN = 'text/markdown';
const JSON_TYPE = 'application/json';
const MARKDOWN_TYPE = 'text/markdown; charset=utf-8';

export const PAGES = ['/', '/docs', '/faq', '/privacy', '/terms'];

export const PAGE_MARKDOWN = [
  '/index.md',
  '/docs.md',
  '/faq.md',
  '/privacy.md',
  '/terms.md',
  '/404.md',
];

const API_PREFIXES = ['/send', '/keys', '/devices', '/history', '/socket', '/reviews', '/download'];

function markdownPath(pathname: string): string {
  const clean = pathname.replace(/\/+$/, '');
  return clean === '' ? '/index.md' : `${clean}.md`;
}

function assetRequest(c: Context<AppEnv>, pathname: string): Request {
  const url = new URL(c.req.url);
  url.pathname = pathname;
  url.search = '';
  const headers = new Headers(c.req.raw.headers);
  headers.delete('If-None-Match');
  headers.delete('If-Modified-Since');
  headers.delete('If-Range');
  headers.delete('Range');
  return new Request(url.toString(), {
    method: c.req.method === 'HEAD' ? 'HEAD' : 'GET',
    headers,
  });
}

function notAcceptable(available: string[]): Response {
  const body = `Not Acceptable\n\nThis URL is available as:\n${available
    .map((type) => `- ${type}`)
    .join('\n')}\n`;
  const res = new Response(body, {
    status: 406,
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'no-store',
    },
  });
  appendVaryAccept(res.headers);
  return res;
}

function asMarkdown(upstream: Response): Response {
  const res = new Response(upstream.body, upstream);
  res.headers.set('Content-Type', MARKDOWN_TYPE);
  appendVaryAccept(res.headers);
  return res;
}

export async function serveMarkdownAsset(c: Context<AppEnv>, pathname: string): Promise<Response> {
  const upstream = await c.env.ASSETS.fetch(assetRequest(c, pathname));
  if (upstream.status !== 200) return upstream;
  return asMarkdown(upstream);
}

async function servePage(c: Context<AppEnv>): Promise<Response> {
  const accept = c.req.header('Accept');
  const chosen = preferredType(accept, [HTML, MARKDOWN]);

  if (chosen === null) return notAcceptable([HTML, MARKDOWN]);

  const mdPath = markdownPath(new URL(c.req.url).pathname);

  if (chosen === MARKDOWN) {
    const upstream = await c.env.ASSETS.fetch(assetRequest(c, mdPath));
    if (upstream.status === 200) return asMarkdown(upstream);
    if (!preferredType(accept, [HTML])) return notAcceptable([HTML]);
  }

  const upstream = await c.env.ASSETS.fetch(c.req.raw);
  const res = new Response(upstream.body, upstream);
  appendVaryAccept(res.headers);
  if (res.headers.get('Content-Type')?.includes(HTML)) {
    const link = `<${mdPath}>; rel="alternate"; type="text/markdown"`;
    const existing = res.headers.get('Link');
    res.headers.set('Link', existing ? `${existing}, ${link}` : link);
  }
  return res;
}

export function isSitePath(pathname: string): boolean {
  return (
    PAGES.includes(pathname) || PAGE_MARKDOWN.includes(pathname) || pathname === '/llms.txt'
  );
}

export function isApiPath(pathname: string): boolean {
  return API_PREFIXES.some(
    (prefix) => pathname === prefix || pathname.startsWith(`${prefix}/`),
  );
}

export async function notFound(c: Context<AppEnv>): Promise<Response> {
  const pathname = new URL(c.req.url).pathname;
  const method = c.req.method;
  const jsonOnly = isApiPath(pathname) || (method !== 'GET' && method !== 'HEAD');
  const accept = c.req.header('Accept');
  const chosen = jsonOnly
    ? JSON_TYPE
    : preferredType(accept, [MARKDOWN, HTML, JSON_TYPE]);

  if (chosen === null) return notAcceptable([MARKDOWN, HTML, JSON_TYPE]);

  if (chosen === JSON_TYPE) {
    const res = c.json(errBody('not_found', t(c).api.notFound), 404);
    if (!jsonOnly) appendVaryAccept(res.headers);
    return res;
  }

  const upstream = await c.env.ASSETS.fetch(
    assetRequest(c, chosen === MARKDOWN ? '/404.md' : '/404.html'),
  );
  if (upstream.status !== 200) {
    return c.json(errBody('not_found', t(c).api.notFound), 404);
  }

  const res = new Response(upstream.body, {
    status: 404,
    headers: upstream.headers,
  });
  res.headers.set(
    'Content-Type',
    chosen === MARKDOWN ? MARKDOWN_TYPE : 'text/html; charset=utf-8',
  );
  res.headers.set('Cache-Control', 'no-store');
  res.headers.delete('ETag');
  res.headers.delete('Last-Modified');
  appendVaryAccept(res.headers);
  return res;
}

export const site = new Hono<AppEnv>();

site.on(['GET', 'HEAD'], PAGES, (c) => servePage(c));

site.on(['GET', 'HEAD'], PAGE_MARKDOWN, (c) =>
  serveMarkdownAsset(c, new URL(c.req.url).pathname),
);

site.on(['GET', 'HEAD'], '/llms.txt', async (c) => {
  const accept = c.req.header('Accept');
  const chosen = preferredType(accept, ['text/plain', MARKDOWN]);
  if (chosen === null) return notAcceptable(['text/plain', MARKDOWN]);
  const upstream = await c.env.ASSETS.fetch(assetRequest(c, '/llms.txt'));
  const res = new Response(upstream.body, upstream);
  res.headers.set(
    'Content-Type',
    chosen === MARKDOWN ? MARKDOWN_TYPE : 'text/plain; charset=utf-8',
  );
  appendVaryAccept(res.headers);
  return res;
});
