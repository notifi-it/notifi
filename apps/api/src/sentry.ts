import type { CloudflareOptions, ErrorEvent, Event } from '@sentry/cloudflare';
import { installConsoleCapture } from './lib/report.js';
import type { Env } from './types.js';

installConsoleCapture();

/// A send key is a bearer credential and it travels in places an error reporter
/// collects by default. The documented one-liner puts it in the query string
/// (`/send?key=nk_...`, and `send.ts` merges the query over the body), the app
/// and the recommended form put it in an `Authorization` header, and either can
/// be attached to an event by the request-data integration.
///
/// Sentry's own scrubbing works from a denylist of field names -- `password`,
/// `token`, `api_key`. It does not cover a parameter called `key`, and it does
/// not look inside a URL at all. So the stripping below is the whole of it.
///
/// The four-character prefix (`nk_a1b2`) is shown in the app's key list and is
/// not a credential; requiring eight characters leaves it readable, which is
/// what makes an event say which key was involved.
const SEND_KEY = /nk_[A-Za-z0-9_-]{8,}/g;

/// A key is replaced by the first eight hex of its SHA-256 rather than by a
/// constant, so that "these forty failures are all one key" is a question the
/// events can answer. Dropping the key entirely makes every event look alike;
/// keeping any part of it stores a credential.
///
/// A hash is safe here in a way it would not be for an email address or an IP.
/// Those have little entropy, so a hash of one is a pseudonym anybody can
/// reverse with a dictionary. A send key is 32 bytes from `getRandomValues`,
/// and there is no dictionary for that.
///
/// It is the same digest `hashKey` writes to `keys.secret_hash`, so the token
/// is also the way back to the row when a report justifies looking:
///
///     SELECT prefix, device_id, revoked_at FROM keys WHERE secret_hash LIKE 'a1b2c3d4%'
///
/// Eight hex is 32 bits. Two live keys colliding is possible and costs nothing
/// -- two keys look like one in a search -- while a longer token would sit in
/// Sentry as a complete database lookup value.
async function token(key: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  const hex = [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, '0')).join('');
  // Deliberately not `nk_a1b2c3d4`. The app's key list shows a real four-character
  // prefix in exactly that shape, and a token that reads like one invites
  // somebody to compare the two and conclude the wrong thing.
  return `key#${hex.slice(0, 8)}`;
}

/// Depth is bounded because this runs on every event and the shape is Sentry's,
/// not ours; 8 clears a stack frame's vars without trusting the input.
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
    // Read before dropping: the query string and the `Authorization` header are
    // where the key of the request that failed actually is, and every other
    // sighting is incidental. Tagging with this one is what makes a search by
    // key find the send that went wrong rather than a mention of it.
    const header = request.headers?.Authorization ?? request.headers?.authorization;
    sent =
      (typeof request.url === 'string' ? (request.url.match(SEND_KEY) ?? [])[0] : undefined) ??
      (typeof header === 'string' ? (header.match(SEND_KEY) ?? [])[0] : undefined);
    if (sent) found.add(sent);

    // Headers carry the bearer key, and a body carries the message the sender
    // wrote -- which `send.ts` seals to the device precisely so that nothing
    // here can read it. Neither is worth a debugging detail.
    request.headers = undefined;
    request.cookies = undefined;
    request.data = undefined;
    request.query_string = undefined;
    if (typeof request.url === 'string') {
      const cut = request.url.indexOf('?');
      if (cut !== -1) request.url = request.url.slice(0, cut);
    }
  }

  // Everything else -- breadcrumbs, tags, the message, a stack frame that
  // captured a URL -- is walked rather than enumerated, because the places a
  // key can reach are a property of Sentry's event shape and change with it.
  // Two passes: the digest is async and the walk is not, so the first pass only
  // collects.
  walk(event, (s) => {
    for (const match of s.match(SEND_KEY) ?? []) found.add(match);
  });
  if (found.size === 0) return event;

  const tokens = new Map(await Promise.all([...found].map(async (k) => [k, await token(k)] as const)));
  walk(event, (s) => s.replace(SEND_KEY, (match) => tokens.get(match) ?? 'key#unknown'));

  const tagged = sent ?? (found.size === 1 ? [...found][0] : undefined);
  // A tag, never the fingerprint. Grouping by key would split one broken
  // deploy into an issue per sender, which is the fragmentation report.ts
  // exists to avoid.
  if (tagged) event.tags = { ...event.tags, send_key: tokens.get(tagged) as string };
  return event;
}

/// Shared by the Worker and the Durable Object so both report into the same
/// project with the same redaction. Without a DSN -- `wrangler dev`, and any
/// environment where the secret has not been set -- the SDK initialises inert
/// and nothing leaves the isolate.
export function sentryOptions(env: Env): CloudflareOptions {
  return {
    dsn: env.SENTRY_DSN,
    environment: env.SENTRY_ENVIRONMENT,
    release: env.SENTRY_RELEASE,
    // The IP address and the request body. Cloudflare logs the former either
    // way and privacy.html says so; there is no reason for a second copy here,
    // and the latter is the message itself.
    sendDefaultPii: false,
    // Errors only. Tracing on a Worker whose one slow dependency is APNs would
    // add a per-request cost and a second thing to reason about before the
    // first question -- what is failing -- has been answered.
    tracesSampleRate: 0,
    // Async because the digest is. Sentry awaits a thenable here, and the
    // Cloudflare client holds the request open until the send settles.
    beforeSend: (event: ErrorEvent) => redact(event),
  };
}
