import { HISTORY_LIMIT_DEFAULT, type HistoryMessage, historyQuery } from '@notifi/contract';
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
  const ack = parsed.data.ack ?? 0;
  const limit = parsed.data.limit ?? HISTORY_LIMIT_DEFAULT;

  if (ack > 0 && ack <= device.seq_counter) {
    const [, deleted] = await c.env.DB.batch([
      c.env.DB.prepare(
        'UPDATE devices SET acked_id = MAX(acked_id, ?), last_seen_at = ? WHERE id = ?',
      ).bind(ack, nowS, device.id),
      c.env.DB.prepare('DELETE FROM messages WHERE device_id = ? AND device_seq <= ?').bind(
        device.id,
        ack,
      ),
    ]);
    const collected = deleted?.meta.changes ?? 0;
    if (collected > 0) {
      c.env.COLLECT_EVENTS.writeDataPoint({
        indexes: [String(device.id)],
        doubles: [collected],
      });
    }
  }

  const rows = await c.env.DB.prepare(
    `SELECT device_seq AS id, content_sealed, key_id, created_at, occurred_at
     FROM messages WHERE device_id = ? ORDER BY device_seq ASC LIMIT ?`,
  )
    .bind(device.id, limit)
    .all<HistoryMessage>();

  const results = rows.results;
  const latest = results.length > 0 ? results[results.length - 1]!.id : null;

  return c.json({ messages: results, latest_id: latest });
});
