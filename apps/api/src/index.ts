import { negotiate } from '@notifi/copy';
import { instrumentDurableObjectWithSentry, withSentry } from '@sentry/cloudflare';
import { Hono } from 'hono';
import { errBody, t } from './lib/respond.js';
import { ipLimiter } from './middleware.js';
import { devices } from './routes/devices.js';
import { downloads } from './routes/downloads.js';
import { history } from './routes/history.js';
import { keys } from './routes/keys.js';
import { refreshReviews, reviews } from './routes/reviews.js';
import { send } from './routes/send.js';
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

app.use('*', ipLimiter);

app.route('/', send);
app.route('/', devices);
app.route('/', keys);
app.route('/', history);
app.route('/', downloads);
app.route('/', reviews);
app.route('/', socket);

app.notFound((c) => c.json(errBody('not_found', t(c).api.notFound), 404));

app.onError((err, c) => {
  console.error('http.unhandled', err, { method: c.req.method, route: c.req.routePath });
  return c.json(errBody('internal_error', t(c).api.unexpected), 500);
});

async function scheduled(_event: ScheduledController, env: Env): Promise<void> {
  await refreshReviews(env);
}

export default withSentry(sentryOptions, {
  fetch: app.fetch,
  scheduled,
});

export const DeviceSocket = instrumentDurableObjectWithSentry(sentryOptions, DeviceSocketBase);

export const ApnsToken = instrumentDurableObjectWithSentry(sentryOptions, ApnsTokenBase);
