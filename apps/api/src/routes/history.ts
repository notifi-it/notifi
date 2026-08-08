import { type HistoryMessage, historyQuery } from '@notifi/contract';
import { Hono } from 'hono';
import { errBody, t } from '../lib/respond.js';
import { now } from '../lib/time.js';
import { getDevice, signatureAuth } from '../middleware.js';
import type { AppEnv } from '../types.js';

export const history = new Hono<AppEnv>();

history.use('/history', signatureAuth);

history.get('/history', async (c) => {
  const nowS = now();
  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', t(c).api.unknownDevice), 401);

  const parsed = historyQuery.safeParse(c.req.query());
  if (!parsed.success) {
    return c.json(errBody('invalid_request', t(c).api.invalidHistoryQuery), 400);
  }
  const since = parsed.data.since ?? 0;
  const limit = parsed.data.limit ?? 50;

  // device_seq is the only id the device ever sees. The global rowid stays
  // server-side — see migration 0005.
  const rows = await c.env.DB.prepare(
    `SELECT device_seq AS id, content_sealed, key_id, created_at, occurred_at
     FROM messages WHERE device_id = ? AND device_seq > ? ORDER BY device_seq ASC LIMIT ?`,
  )
    .bind(device.id, since, limit)
    .all<HistoryMessage>();

  const results = rows.results;
  const latest = results.length > 0 ? results[results.length - 1]!.id : null;

  // The overwhelming majority of syncs find nothing and confirm nothing, and
  // this used to write on every one of them. Now it writes only when the device
  // has actually collected something — which is what `acked_id` means, and what
  // the nightly delete keys off.
  //
  // `last_seen_at` is deliberately not touched here. It feeds the 30-day
  // abandoned-device sweep, and a routine sync says nothing about
  // whether the device is still wanted; /devices sets it on every launch and
  // /keys refreshes it when stale, which is what "seen" is supposed to mean. An
  // idle sync is now reads only.
  if (since > device.acked_id) {
    await c.env.DB.prepare(
      'UPDATE devices SET acked_id = MAX(acked_id, ?), last_seen_at = ? WHERE id = ?',
    )
      .bind(since, nowS, device.id)
      .run();
  }

  return c.json({ messages: results, latest_id: latest });
});
