import { type MessageContent, sendParams } from '@notifi/contract';
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
  device_id: number;
  apns_token: string;
  encryption_public_key: string;
}

function pushPayload(id: number, sealedB64: string, keyId: number): object {
  return {
    aps: {
      alert: { title: 'notifi' },
      sound: 'default',
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
    `SELECT k.id AS key_id, k.revoked_at AS revoked_at,
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
  const content: MessageContent = {
    title: input.title,
    ...(input.message !== undefined ? { message: input.message } : {}),
    ...(input.link !== undefined ? { link: input.link } : {}),
    ...(input.image !== undefined ? { image: input.image } : {}),
    key_id: row.key_id,
    created_at: createdAt,
  };
  const fullSealed = await seal(row.encryption_public_key, 'content', JSON.stringify(content));

  const expiresAt = nowS + MESSAGE_BACKSTOP_S;
  const message = await c.env.DB.prepare(
    `INSERT INTO messages (device_id, key_id, content_sealed, created_at, expires_at)
     VALUES (?, ?, ?, ?, ?) RETURNING id`,
  )
    .bind(row.device_id, row.key_id, fullSealed, createdAt, expiresAt)
    .first<{ id: number }>();

  const messageId = message!.id;

  const fallbacks: MessageContent[] = [
    {
      title: input.title,
      ...(input.message !== undefined
        ? { message: input.message.slice(0, PREVIEW_MESSAGE_MAX) }
        : {}),
      ...(input.image !== undefined ? { image: input.image } : {}),
      key_id: row.key_id,
      created_at: createdAt,
    },
    {
      title: input.title,
      ...(input.message !== undefined
        ? { message: input.message.slice(0, MINIMAL_MESSAGE_MAX) }
        : {}),
      key_id: row.key_id,
      created_at: createdAt,
    },
    {
      title: input.title,
      key_id: row.key_id,
      created_at: createdAt,
    },
  ];

  let payload = pushPayload(messageId, fullSealed, row.key_id);
  for (const candidate of fallbacks) {
    if (payloadBytes(payload) <= PUSH_BUDGET_BYTES) break;
    const sealed = await seal(row.encryption_public_key, 'content', JSON.stringify(candidate));
    payload = pushPayload(messageId, sealed, row.key_id);
  }

  await push(
    c.env,
    c.env.DB,
    { id: row.device_id, apns_token: row.apns_token },
    payload,
    expiresAt,
    nowS,
  );

  return c.json({ id: messageId }, 202);
});
