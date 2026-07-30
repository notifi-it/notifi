import { createKeyBody, type KeyMeta, type KeySummary } from '@notifi/contract';
import { Hono } from 'hono';
import { errBody } from '../lib/respond.js';
import { seal } from '../lib/seal.js';
import { generateSendKey } from '../lib/sendkey.js';
import { now } from '../lib/time.js';
import { bumpLastSeenIfStale, getDevice, signatureAuth } from '../middleware.js';
import type { AppEnv } from '../types.js';

const MAX_ACTIVE_KEYS = 50;

export const keys = new Hono<AppEnv>();

keys.use('/keys', signatureAuth);
keys.use('/keys/*', signatureAuth);

keys.get('/keys', async (c) => {
  const nowS = now();
  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', 'Device is not registered.'), 401);

  const rows = await c.env.DB.prepare(
    `SELECT id, meta_sealed, created_at, last_used_at, sent_count, revoked_at
     FROM keys WHERE device_id = ? ORDER BY id DESC`,
  )
    .bind(device.id)
    .all<KeySummary>();

  await bumpLastSeenIfStale(c.env, device, nowS);
  return c.json({ keys: rows.results });
});

keys.post('/keys', async (c) => {
  const nowS = now();
  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', 'Device is not registered.'), 401);

  let parsed;
  try {
    const text = new TextDecoder().decode(c.get('rawBody'));
    parsed = createKeyBody.parse(JSON.parse(text));
  } catch {
    return c.json(errBody('invalid_request', 'Invalid create-key body.'), 400);
  }

  const active = await c.env.DB.prepare(
    'SELECT COUNT(*) AS n FROM keys WHERE device_id = ? AND revoked_at IS NULL',
  )
    .bind(device.id)
    .first<{ n: number }>();
  if ((active?.n ?? 0) >= MAX_ACTIVE_KEYS) {
    return c.json(errBody('invalid_request', 'Active key limit reached.'), 400);
  }

  const generated = await generateSendKey();

  const inserted = await c.env.DB.prepare(
    `INSERT INTO keys (device_id, meta_sealed, secret_hash, created_at)
     VALUES (?, '', ?, ?) RETURNING id`,
  )
    .bind(device.id, generated.secretHash, nowS)
    .first<{ id: number }>();

  const id = inserted!.id;
  const meta: KeyMeta = { id, name: parsed.name, prefix: generated.prefix };
  const metaSealed = await seal(device.encryption_public_key, 'key_meta', JSON.stringify(meta));

  await c.env.DB.prepare('UPDATE keys SET meta_sealed = ? WHERE id = ?').bind(metaSealed, id).run();

  await bumpLastSeenIfStale(c.env, device, nowS);
  return c.json({ id, name: parsed.name, key: generated.key }, 200);
});

keys.delete('/keys/:id', async (c) => {
  const nowS = now();
  const device = await getDevice(c);
  if (!device) return c.json(errBody('unknown_device', 'Device is not registered.'), 401);

  const id = Number(c.req.param('id'));
  if (!Number.isInteger(id)) {
    return c.json(errBody('not_found', 'Key not found.'), 404);
  }

  const revoked = await c.env.DB.prepare(
    `UPDATE keys SET revoked_at = ?
     WHERE id = ? AND device_id = ? AND revoked_at IS NULL RETURNING id`,
  )
    .bind(nowS, id, device.id)
    .first<{ id: number }>();

  if (!revoked) {
    return c.json(errBody('not_found', 'Key not found.'), 404);
  }

  await bumpLastSeenIfStale(c.env, device, nowS);
  return c.body(null, 204);
});
