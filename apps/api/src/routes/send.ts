import {
  type MessageContent,
  OCCURRED_AT_MAX_SKEW_MS,
  sendParams,
} from '@notifi/contract';
import { Hono } from 'hono';
import { push } from '../lib/apns.js';
import { errBody } from '../lib/respond.js';
import { seal } from '../lib/seal.js';
import { hashKey } from '../lib/sendkey.js';
import {
  MESSAGE_BACKSTOP_S,
  now,
  PER_KEY_LIMIT,
  PER_KEY_WINDOW_S,
  windowStart,
} from '../lib/time.js';
import type { AppEnv } from '../types.js';

const PUSH_BUDGET_BYTES = 4000;
const PREVIEW_MESSAGE_MAX = 1000;
const MINIMAL_MESSAGE_MAX = 200;

interface KeyDeviceRow {
  key_id: number;
  revoked_at: number | null;
  critical: number;
  device_id: number;
  apns_token: string;
  encryption_public_key: string;
}

function pushPayload(
  id: number,
  sealedB64: string,
  keyId: number,
  critical: boolean,
): object {
  return {
    aps: {
      alert: { title: 'notifi' },
      // A critical sound is an object rather than a name, and it is what makes
      // the alert audible through the ringer switch. `interruption-level` alone
      // would get it past Focus but leave it silent on a muted phone, which for
      // a pager is the same as not arriving.
      sound: critical ? { critical: 1, name: 'default', volume: 1 } : 'default',
      ...(critical ? { 'interruption-level': 'critical' } : {}),
      'mutable-content': 1,
      'thread-id': `key-${keyId}`,
    },
    notifi: { id, sealed: sealedB64 },
  };
}

function payloadBytes(payload: object): number {
  return new TextEncoder().encode(JSON.stringify(payload)).length;
}

export const send = new Hono<AppEnv>();

send.use('/send', async (c, next) => {
  c.header('Access-Control-Allow-Origin', '*');
  c.header('Cache-Control', 'no-store');
  return next();
});

send.options('/send', (c) => {
  c.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  c.header('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  return c.body(null, 204);
});

send.on(['GET', 'POST'], '/send', async (c) => {
  const nowS = now();

  let bodyParams: Record<string, unknown> = {};
  if (c.req.method === 'POST') {
    const contentType = c.req.header('content-type') ?? '';
    if (contentType.includes('application/json')) {
      try {
        bodyParams = (await c.req.json()) as Record<string, unknown>;
      } catch {
        bodyParams = {};
      }
    } else {
      try {
        bodyParams = (await c.req.parseBody()) as Record<string, unknown>;
      } catch {
        bodyParams = {};
      }
    }
  }

  const merged: Record<string, unknown> = { ...bodyParams, ...c.req.query() };

  const auth = c.req.header('authorization');
  const bearer =
    auth && auth.toLowerCase().startsWith('bearer ') ? auth.slice(7).trim() : undefined;
  if (merged.key === undefined && bearer) merged.key = bearer;

  const parsed = sendParams.safeParse(merged);
  if (!parsed.success) {
    return c.json(errBody('invalid_request', 'Invalid send parameters.'), 400);
  }
  const input = parsed.data;

  const secretHash = await hashKey(input.key);
  const row = await c.env.DB.prepare(
    `SELECT k.id AS key_id, k.revoked_at AS revoked_at, k.critical AS critical,
            d.id AS device_id, d.apns_token AS apns_token,
            d.encryption_public_key AS encryption_public_key
     FROM keys k JOIN devices d ON d.id = k.device_id
     WHERE k.secret_hash = ?`,
  )
    .bind(secretHash)
    .first<KeyDeviceRow>();

  if (!row || row.revoked_at !== null) {
    return c.json(errBody('unknown_key', 'Unknown or revoked key.'), 401);
  }

  const w = windowStart(nowS);
  const updated = await c.env.DB.prepare(
    `UPDATE keys SET
       rl_window_count = CASE WHEN rl_window_start = ? THEN rl_window_count + 1 ELSE 1 END,
       rl_window_start = ?,
       sent_count      = sent_count + 1,
       last_used_at    = ?
     WHERE id = ? AND revoked_at IS NULL
       AND (rl_window_start != ? OR rl_window_count < ?)
     RETURNING id`,
  )
    .bind(w, w, nowS, row.key_id, w, PER_KEY_LIMIT)
    .first<{ id: number }>();

  if (!updated) {
    const still = await c.env.DB.prepare('SELECT revoked_at FROM keys WHERE id = ?')
      .bind(row.key_id)
      .first<{ revoked_at: number | null }>();
    if (!still || still.revoked_at !== null) {
      return c.json(errBody('unknown_key', 'Unknown or revoked key.'), 401);
    }
    c.header('Retry-After', String(w + PER_KEY_WINDOW_S - nowS));
    return c.json(errBody('rate_limited', 'Per-key rate limit exceeded.'), 429);
  }

  const createdAt = nowS;

  // The upper bound needs the server clock, so it is checked here rather than in
  // the schema. A little skew is normal; a week in the future is not.
  const occurredAt = input.occurred_at;
  if (occurredAt !== undefined && occurredAt > nowS * 1000 + OCCURRED_AT_MAX_SKEW_MS) {
    return c.json(
      errBody('invalid_request', 'occurred_at is too far in the future.'),
      400,
    );
  }

  const content: MessageContent = {
    title: input.title,
    ...(input.message !== undefined ? { message: input.message } : {}),
    ...(input.link !== undefined ? { link: input.link } : {}),
    ...(input.image !== undefined ? { image: input.image } : {}),
    key_id: row.key_id,
    created_at: createdAt,
    ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
  };
  const fullSealed = await seal(row.encryption_public_key, 'content', JSON.stringify(content));

  const expiresAt = nowS + MESSAGE_BACKSTOP_S;

  // Allocate the device's next number first, and take it from the RETURNING
  // rather than reading the counter back. Two sends racing on one device would
  // otherwise both read the same value and collide on the unique index.
  // A number burned by a failed insert leaves a gap, which is harmless: the
  // device asks for everything above its bookmark, not for a dense run.
  const counter = await c.env.DB.prepare(
    'UPDATE devices SET seq_counter = seq_counter + 1 WHERE id = ? RETURNING seq_counter',
  )
    .bind(row.device_id)
    .first<{ seq_counter: number }>();

  if (!counter) {
    return c.json(errBody('unknown_key', 'Unknown or revoked key.'), 401);
  }
  const deviceSeq = counter.seq_counter;

  await c.env.DB.prepare(
    `INSERT INTO messages
       (device_id, device_seq, key_id, content_sealed, created_at, expires_at, occurred_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      row.device_id,
      deviceSeq,
      row.key_id,
      fullSealed,
      createdAt,
      expiresAt,
      occurredAt ?? null,
    )
    .run();

  const messageId = deviceSeq;

  const fallbacks: MessageContent[] = [
    {
      title: input.title,
      ...(input.message !== undefined
        ? { message: input.message.slice(0, PREVIEW_MESSAGE_MAX) }
        : {}),
      ...(input.image !== undefined ? { image: input.image } : {}),
      key_id: row.key_id,
      created_at: createdAt,
      // Every fallback has to carry occurred_at too. The app checks the sealed
      // copy against the row, so a payload that dropped it would be treated as
      // tampered and skipped.
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
    },
    {
      title: input.title,
      ...(input.message !== undefined
        ? { message: input.message.slice(0, MINIMAL_MESSAGE_MAX) }
        : {}),
      key_id: row.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
    },
    {
      title: input.title,
      key_id: row.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
    },
  ];

  // Both halves have to agree: the sender asks per message, the device owner
  // allows it per key. A send key that leaks cannot raise its own volume, and a
  // key marked critical stays quiet for the ordinary sends that share it.
  const critical = input.critical === true && row.critical === 1;

  let payload = pushPayload(messageId, fullSealed, row.key_id, critical);
  for (const candidate of fallbacks) {
    if (payloadBytes(payload) <= PUSH_BUDGET_BYTES) break;
    const sealed = await seal(row.encryption_public_key, 'content', JSON.stringify(candidate));
    payload = pushPayload(messageId, sealed, row.key_id, critical);
  }

  await push(
    c.env,
    c.env.DB,
    { id: row.device_id, apns_token: row.apns_token },
    payload,
    expiresAt,
    nowS,
  );

  // Deliberately no id. It is now per-device rather than global, so returning it
  // would no longer leak the relay's traffic — it would leak the recipient's,
  // telling any one sender how much everything else sends to that device.
  return c.json({ ok: true }, 202);
});
