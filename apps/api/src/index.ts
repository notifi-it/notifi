import { Hono } from 'hono';
import { errBody } from './lib/respond.js';
import { ABANDONED_DEVICE_S, now } from './lib/time.js';
import { ipLimiter } from './middleware.js';
import { devices } from './routes/devices.js';
import { history } from './routes/history.js';
import { keys } from './routes/keys.js';
import { send } from './routes/send.js';
import type { AppEnv, Env } from './types.js';

const app = new Hono<AppEnv>();

app.use('*', ipLimiter);

app.route('/', send);
app.route('/', devices);
app.route('/', keys);
app.route('/', history);

app.notFound((c) => c.json(errBody('not_found', 'Not found.'), 404));

app.onError((err, c) => {
  console.error('unhandled', String(err));
  return c.json(errBody('invalid_request', 'Unexpected error.'), 500);
});

async function scheduled(_event: ScheduledController, env: Env): Promise<void> {
  const nowS = now();

  for (;;) {
    const res = await env.DB.prepare(
      `DELETE FROM messages WHERE id IN (
         SELECT m.id FROM messages m JOIN devices d ON d.id = m.device_id
         WHERE m.id <= d.acked_id LIMIT 1000
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
     WHERE last_seen_at < ? AND id NOT IN (SELECT DISTINCT device_id FROM keys)`,
  )
    .bind(nowS - ABANDONED_DEVICE_S)
    .run();
}

export default {
  fetch: app.fetch,
  scheduled,
};
