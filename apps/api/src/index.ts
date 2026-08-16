import { negotiate } from '@notifi/copy';
import { instrumentDurableObjectWithSentry, withSentry } from '@sentry/cloudflare';
import { Hono } from 'hono';
import { errBody, t } from './lib/respond.js';
import { now } from './lib/time.js';
import { ipLimiter } from './middleware.js';
import { devices } from './routes/devices.js';
import { downloads } from './routes/downloads.js';
import { history } from './routes/history.js';
import { keys } from './routes/keys.js';
import { send } from './routes/send.js';
import { socket } from './routes/socket.js';
import { sentryOptions } from './sentry.js';
import { DeviceSocket as DeviceSocketBase } from './socket.js';
import type { AppEnv, Env } from './types.js';

const app = new Hono<AppEnv>();

app.use('*', async (c, next) => {
  const url = new URL(c.req.url);
  const loopback = url.hostname === 'localhost' || url.hostname === '127.0.0.1';
  if (url.protocol === 'http:' && !loopback) {
    url.protocol = 'https:';
    return c.redirect(url.toString(), 301);
  }
  await next();
  c.header('Strict-Transport-Security', 'max-age=31536000; includeSubDomains');
});

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
app.route('/', socket);

app.notFound((c) => c.json(errBody('not_found', t(c).api.notFound), 404));

// Nothing reaches the Worker boundary Sentry instruments: this answers every
// exception with a 500 and returns normally. The report is the `console.error`,
// which is also why it is handed the error itself rather than `String(err)` --
// that is where the stack comes from.
app.onError((err, c) => {
  console.error('http.unhandled', err, { method: c.req.method, route: c.req.routePath });
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

}

// `withSentry` instruments `scheduled` as well as `fetch`, so a cron that
// throws is reported without a handler of its own. It also has a Hono hook, but
// that one only fires when the exported handler *is* the app; this exports a
// plain object, and `app.onError` above reports with tags the hook cannot know.
export default withSentry(sentryOptions, {
  fetch: app.fetch,
  scheduled,
});

// The Durable Object is a separate entry point in the same Worker: an exception
// in a socket handler never passes through `fetch`, so it needs instrumenting
// on its own. The name is what `wrangler.toml` binds, so it is exported here
// rather than from socket.ts.
export const DeviceSocket = instrumentDurableObjectWithSentry(sentryOptions, DeviceSocketBase);
