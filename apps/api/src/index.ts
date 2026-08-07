import { negotiate } from '@notifi/copy';
import { Hono } from 'hono';
import { errBody, t } from './lib/respond.js';
import { ABANDONED_DEVICE_S, now } from './lib/time.js';
import { ipLimiter } from './middleware.js';
import { devices } from './routes/devices.js';
import { downloads } from './routes/downloads.js';
import { history } from './routes/history.js';
import { keys } from './routes/keys.js';
import { send } from './routes/send.js';
import type { AppEnv, Env } from './types.js';

const app = new Hono<AppEnv>();

/// Cleartext is a key leak: a send key travels in the query string or an
/// Authorization header, and over http both are readable by anything on the
/// path. Redirect rather than serve, and set HSTS so a browser never tries
/// http again. This replaces the zone-level `always_use_https` that
/// infra/main.tf declared but never applied.
///
/// Cloudflare terminates TLS, so the scheme has to come off the URL the Worker
/// was handed, not off the socket.
app.use('*', async (c, next) => {
  const url = new URL(c.req.url);
  if (url.protocol === 'http:') {
    url.protocol = 'https:';
    // 301, not 307: this is permanent, and every method that reaches /send is
    // safe to re-issue. Browsers and curl -L both follow it.
    return c.redirect(url.toString(), 301);
  }
  await next();
  c.header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
});

// Negotiated once, before anything can answer. Every user-facing message is read
// through `t(c)`, so a handler cannot accidentally answer in a language of its own.
app.use('*', async (c, next) => {
  c.set('language', negotiate(c.req.header('Accept-Language')));
  await next();
});

app.use('*', ipLimiter);

app.route('/', send);
app.route('/', devices);
app.route('/', keys);
app.route('/', history);
app.route('/', downloads);

app.notFound((c) => c.json(errBody('not_found', t(c).api.notFound), 404));

app.onError((err, c) => {
  console.error('unhandled', String(err));
  return c.json(errBody('internal_error', t(c).api.unexpected), 500);
});

async function scheduled(_event: ScheduledController, env: Env): Promise<void> {
  const nowS = now();

  for (;;) {
    const res = await env.DB.prepare(
      `DELETE FROM messages WHERE id IN (
         SELECT m.id FROM messages m JOIN devices d ON d.id = m.device_id
         WHERE m.device_seq <= d.acked_id LIMIT 1000
       )`,
    ).run();
    if ((res.meta.changes ?? 0) < 1000) break;
  }

  for (;;) {
    const res = await env.DB.prepare(
      'DELETE FROM messages WHERE id IN (SELECT id FROM messages WHERE expires_at < ? LIMIT 1000)',
    )
      .bind(nowS)
      .run();
    if ((res.meta.changes ?? 0) < 1000) break;
  }

  await env.DB.prepare(
    `DELETE FROM devices
     WHERE last_seen_at < ?
       AND id NOT IN (SELECT DISTINCT device_id FROM keys WHERE revoked_at IS NULL)`,
  )
    .bind(nowS - ABANDONED_DEVICE_S)
    .run();

  await env.DB.prepare('DELETE FROM seen_signatures WHERE expires_at < ?').bind(nowS).run();
}

export default {
  fetch: app.fetch,
  scheduled,
};
