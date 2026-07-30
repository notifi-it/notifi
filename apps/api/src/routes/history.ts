import { type HistoryMessage, historyQuery } from '@notifi/contract';
import { Hono } from 'hono';
import { errBody } from '../lib/respond.js';
import { now } from '../lib/time.js';
import { bumpLastSeenIfStale, getDevice, signatureAuth } from '../middleware.js';
import type { AppEnv } from '../types.js';

export const history = new Hono<AppEnv>();

history.use('/history', signatureAuth);

history.get('/history', async (c) => {
  const nowS = now();
  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', 'Device is not registered.'), 401);

  const parsed = historyQuery.safeParse(c.req.query());
  if (!parsed.success) {
    return c.json(errBody('invalid_request', 'Invalid history query.'), 400);
  }
  const since = parsed.data.since ?? 0;
  const limit = parsed.data.limit ?? 50;

  const rows = await c.env.DB.prepare(
    `SELECT id, content_sealed, key_id, created_at
     FROM messages WHERE device_id = ? AND id > ? ORDER BY id ASC LIMIT ?`,
  )
    .bind(device.id, since, limit)
    .all<HistoryMessage>();

  const results = rows.results;
  const latest = results.length > 0 ? results[results.length - 1]!.id : null;

  await bumpLastSeenIfStale(c.env, device, nowS);
  return c.json({ messages: results, latest_id: latest });
});
