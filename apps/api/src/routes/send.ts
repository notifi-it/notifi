import {
  type MessageContent,
  OCCURRED_AT_MAX_SKEW_MS,
  sendParams,
} from '@notifi/contract';
import { copyFor, SOURCE_LANGUAGE, type Strings } from '@notifi/copy';
import { Hono } from 'hono';
import { push } from '../lib/apns.js';
import { errBody, t } from '../lib/respond.js';
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

// One switch, two ceilings. `critical` is the one the product wants — audible
// through the ringer switch — but it needs an entitlement Apple has not granted
// (request W8U762V6VJ), and a push claiming an interruption level the app is not
// entitled to is dropped rather than downgraded. `time-sensitive` needs no
// approval and already gets the page past Focus and onto the lock screen, so it
// is what an escalated send means until the grant lands. Flip this the same day
// the entitlement goes into the .entitlements files, not before.
const CRITICAL_ENTITLED = false;

function pushPayload(
  id: number,
  sealedB64: string,
  keyId: number,
  escalate: boolean,
  strings: Strings,
): object {
  const escalation = escalate
    ? CRITICAL_ENTITLED
      ? {
          // A critical sound is an object rather than a name, and it is what
          // makes the alert audible through the ringer switch. The interruption
          // level alone would get it past Focus but leave it silent on a muted
          // phone, which for a pager is the same as not arriving.
          sound: { critical: 1, name: 'default', volume: 1 },
          'interruption-level': 'critical',
        }
      : { sound: 'default', 'interruption-level': 'time-sensitive' }
    : { sound: 'default' };

  return {
    aps: {
      // What the lock screen shows if the service extension never runs. The
      // real title is inside `sealed`, which only the device can open.
      alert: { title: strings.push.fallbackTitle },
      ...escalation,
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
    return c.json(errBody('invalid_request', t(c).api.invalidSendParams), 400);
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
    return c.json(errBody('unknown_key', t(c).api.unknownKey), 401);
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
      return c.json(errBody('unknown_key', t(c).api.unknownKey), 401);
    }
    c.header('Retry-After', String(w + PER_KEY_WINDOW_S - nowS));
    return c.json(errBody('rate_limited', t(c).api.rateLimitedKey), 429);
  }

  const createdAt = nowS;

  // The upper bound needs the server clock, so it is checked here rather than in
  // the schema. A little skew is normal; a week in the future is not.
  const occurredAt = input.occurred_at;
  if (occurredAt !== undefined && occurredAt > nowS * 1000 + OCCURRED_AT_MAX_SKEW_MS) {
    return c.json(
      errBody('invalid_request', t(c).api.occurredAtTooFuture),
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
    return c.json(errBody('unknown_key', t(c).api.unknownKey), 401);
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
  const escalate = input.critical === true && row.critical === 1;

  // Not `t(c)`: this text is read by the recipient, and the request that
  // produced it came from the sender's script, whose Accept-Language says
  // nothing about them. Localising it properly needs the device's language
  // recorded at registration; until then it is the source language, and the
  // service extension replaces it with the decrypted title in almost every case.
  const deviceStrings = copyFor(SOURCE_LANGUAGE);

  let payload = pushPayload(messageId, fullSealed, row.key_id, escalate, deviceStrings);
  for (const candidate of fallbacks) {
    if (payloadBytes(payload) <= PUSH_BUDGET_BYTES) break;
    const sealed = await seal(row.encryption_public_key, 'content', JSON.stringify(candidate));
    payload = pushPayload(messageId, sealed, row.key_id, escalate, deviceStrings);
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
