import type { CloudflareOptions, ErrorEvent, Event } from '@sentry/cloudflare';
import { installConsoleCapture } from './lib/report.js';
import type { Env } from './types.js';

installConsoleCapture();

const SEND_KEY = /nk_[A-Za-z0-9_-]{8,}/g;

async function token(key: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  const hex = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
  return `key#${hex.slice(0, 8)}`;
}

function walk(value: unknown, onString: (s: string) => string | void, depth = 0): unknown {
  if (depth > 8) return value;
  if (typeof value === 'string') return onString(value) ?? value;
  if (Array.isArray(value)) return value.map((item) => walk(item, onString, depth + 1));
  if (typeof value === 'object' && value !== null) {
    for (const [field, inner] of Object.entries(value)) {
      (value as Record<string, unknown>)[field] = walk(inner, onString, depth + 1);
    }
  }
  return value;
}

async function redact<T extends Event>(event: T): Promise<T> {
  const found = new Set<string>();

  const request = event.request;
  let sent: string | undefined;
  if (request) {
    const header = request.headers?.Authorization ?? request.headers?.authorization;
    sent =
      (typeof request.url === 'string' ? (request.url.match(SEND_KEY) ?? [])[0] : undefined) ??
      (typeof header === 'string' ? (header.match(SEND_KEY) ?? [])[0] : undefined);
    if (sent) found.add(sent);

    request.headers = undefined;
    request.cookies = undefined;
    request.data = undefined;
    request.query_string = undefined;
    if (typeof request.url === 'string') {
      const cut = request.url.indexOf('?');
      if (cut !== -1) request.url = request.url.slice(0, cut);
    }
  }

  walk(event, (s) => {
    for (const match of s.match(SEND_KEY) ?? []) found.add(match);
  });
  if (found.size === 0) return event;

  const tokens = new Map(await Promise.all([...found].map(async (k) => [k, await token(k)] as const)));
  walk(event, (s) => s.replace(SEND_KEY, (match) => tokens.get(match) ?? 'key#unknown'));

  const tagged = sent ?? (found.size === 1 ? [...found][0] : undefined);
  if (tagged) event.tags = { ...event.tags, send_key: tokens.get(tagged) as string };
  return event;
}

export function sentryOptions(env: Env): CloudflareOptions {
  return {
    dsn: env.SENTRY_DSN,
    environment: env.SENTRY_ENVIRONMENT,
    release: env.SENTRY_RELEASE,
    sendDefaultPii: false,
    tracesSampleRate: 0,
    beforeSend: (event: ErrorEvent) => redact(event),
  };
}
