import { negotiate } from '@notifi/copy';
import { instrumentDurableObjectWithSentry, withSentry } from '@sentry/cloudflare';
import { Hono } from 'hono';
import { errBody, t } from './lib/respond.js';
import { now, PER_DEVICE_WINDOW_S } from './lib/time.js';
import { ipLimiter } from './middleware.js';
import { devices } from './routes/devices.js';
import { downloads } from './routes/downloads.js';
import { history } from './routes/history.js';
import { keys } from './routes/keys.js';
import { reviews } from './routes/reviews.js';
import { send } from './routes/send.js';
import { isSitePath, notFound, site } from './routes/site.js';
import { socket } from './routes/socket.js';
import { ApnsToken as ApnsTokenBase } from './apnstoken.js';
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

app.use('*', async (c, next) => {
  const method = c.req.method;
  if ((method === 'GET' || method === 'HEAD') && isSitePath(new URL(c.req.url).pathname)) {
    return next();
  }
  return ipLimiter(c, next);
});

app.route('/', send);
app.route('/', devices);
app.route('/', keys);
app.route('/', history);
app.route('/', downloads);
app.route('/', reviews);
app.route('/', socket);
app.route('/', site);

app.notFound(notFound);

app.onError((err, c) => {
  console.error('http.unhandled', err, { method: c.req.method, route: c.req.routePath });
  return c.json(errBody('internal_error', t(c).api.unexpected), 500);
});

export default withSentry(sentryOptions, {
  fetch: app.fetch,
  scheduled: async (_controller, env: Env) => {
    const nowS = now();
    await env.DB.prepare(
      `DELETE FROM messages
       WHERE expires_at <= ? OR (collected_at IS NOT NULL AND created_at <= ?)`,
    )
      .bind(nowS, nowS - PER_DEVICE_WINDOW_S)
      .run();
  },
});

export const DeviceSocket = instrumentDurableObjectWithSentry(sentryOptions, DeviceSocketBase);

export const ApnsToken = instrumentDurableObjectWithSentry(sentryOptions, ApnsTokenBase);
