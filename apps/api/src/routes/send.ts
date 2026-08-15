import {
  MESSAGE_MAX,
  type MessageContent,
  OCCURRED_AT_MAX_SKEW_MS,
  sendParams,
  TITLE_MAX,
} from '@notifi/contract';
import { copyFor, fmt, SOURCE_LANGUAGE, type Strings } from '@notifi/copy';
import { Hono } from 'hono';
import { push } from '../lib/apns.js';
import { checkImage } from '../lib/imagecheck.js';
import { errBody, t } from '../lib/respond.js';
import { seal } from '../lib/seal.js';
import { hashKey } from '../lib/sendkey.js';
import {
  MESSAGE_BACKSTOP_S,
  now,
  PER_DEVICE_LIMIT,
  PER_DEVICE_WINDOW_S,
  windowStart,
} from '../lib/time.js';
import type { AppEnv } from '../types.js';

const PUSH_BUDGET_BYTES = 4000;
const PREVIEW_MESSAGE_MAX = 1000;
const MINIMAL_MESSAGE_MAX = 200;

interface KeyDeviceRow {
  key_id: number;
  revoked_at: number | null;
  is_critical: number;
  device_id: number;
  apns_token: string;
  encryption_public_key: string;
  strict_send: number;
}

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
          sound: { critical: 1, name: 'default', volume: 1 },
          'interruption-level': 'critical',
        }
      : { sound: 'default', 'interruption-level': 'time-sensitive' }
    : { sound: 'default' };

  return {
    aps: {
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
    `SELECT k.id AS key_id, k.revoked_at AS revoked_at, k.is_critical AS is_critical,
            d.id AS device_id, d.apns_token AS apns_token,
            d.encryption_public_key AS encryption_public_key,
            d.strict_send AS strict_send
     FROM keys k JOIN devices d ON d.id = k.device_id
     WHERE k.secret_hash = ?`,
  )
    .bind(secretHash)
    .first<KeyDeviceRow>();

  if (!row || row.revoked_at !== null) {
    return c.json(errBody('unknown_key', t(c).api.unknownKey), 401);
  }

  const w = windowStart(nowS);
  const allowed = await c.env.DB.prepare(
    `UPDATE devices SET
       rl_window_count = CASE WHEN rl_window_start = ? THEN rl_window_count + 1 ELSE 1 END,
       rl_window_start = ?,
       seq_counter     = seq_counter + 1
     WHERE id = ?
       AND (rl_window_start != ? OR rl_window_count < ?)
     RETURNING seq_counter`,
  )
    .bind(w, w, row.device_id, w, PER_DEVICE_LIMIT)
    .first<{ seq_counter: number }>();

  if (!allowed) {
    const still = await c.env.DB.prepare('SELECT id FROM devices WHERE id = ?')
      .bind(row.device_id)
      .first<{ id: number }>();
    if (!still) {
      return c.json(errBody('unknown_key', t(c).api.unknownKey), 401);
    }
    c.header('Retry-After', String(w + PER_DEVICE_WINDOW_S - nowS));
    return c.json(errBody('rate_limited', t(c).api.rateLimitedAccount), 429);
  }
  const deviceSeq = allowed.seq_counter;

  const keyLive = await c.env.DB.prepare(
    `UPDATE keys SET sent_count = sent_count + 1, last_used_at = ?
     WHERE id = ? AND revoked_at IS NULL
     RETURNING id`,
  )
    .bind(nowS, row.key_id)
    .first<{ id: number }>();

  if (!keyLive) {
    return c.json(errBody('unknown_key', t(c).api.unknownKey), 401);
  }

  const createdAt = nowS;

  const occurredAt = input.occurred_at;
  if (occurredAt !== undefined && occurredAt > nowS * 1000 + OCCURRED_AT_MAX_SKEW_MS) {
    return c.json(
      errBody('invalid_request', t(c).api.occurredAtTooFuture),
      400,
    );
  }

  const asked = input.is_critical === true || input.critical === true;
  const critical = asked && row.is_critical === 1;

  const warnings: string[] = [];

  let title = input.title;
  if (title.length > TITLE_MAX) {
    title = title.slice(0, TITLE_MAX);
    warnings.push(fmt(t(c).api.titleCropped, { max: TITLE_MAX }));
  }

  let message = input.message;
  if (message !== undefined && message.length > MESSAGE_MAX) {
    message = message.slice(0, MESSAGE_MAX);
    warnings.push(fmt(t(c).api.messageCropped, { max: MESSAGE_MAX }));
  }

  let image = input.image;
  if (image !== undefined) {
    const rejection = await checkImage(image);
    if (rejection !== null) {
      image = undefined;
      warnings.push(
        rejection === 'rejected' ? t(c).api.imageRejected : t(c).api.imageUnreachable,
      );
    }
  }

  if (row.strict_send === 1 && warnings.length > 0) {
    return c.json(errBody('invalid_content', t(c).api.strictContentRejected), 422);
  }

  const content: MessageContent = {
    title,
    ...(message !== undefined ? { message } : {}),
    ...(input.link !== undefined ? { link: input.link } : {}),
    ...(image !== undefined ? { image } : {}),
    key_id: row.key_id,
    created_at: createdAt,
    ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
    is_critical: critical,
  };
  const fullSealed = await seal(row.encryption_public_key, 'content', JSON.stringify(content));

  const expiresAt = nowS + MESSAGE_BACKSTOP_S;

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
      title,
      ...(message !== undefined ? { message: message.slice(0, PREVIEW_MESSAGE_MAX) } : {}),
      ...(image !== undefined ? { image } : {}),
      key_id: row.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
      is_critical: critical,
    },
    {
      title,
      ...(message !== undefined ? { message: message.slice(0, MINIMAL_MESSAGE_MAX) } : {}),
      key_id: row.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
      is_critical: critical,
    },
    {
      title,
      key_id: row.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
      is_critical: critical,
    },
  ];

  const deviceStrings = copyFor(SOURCE_LANGUAGE);

  let payload = pushPayload(messageId, fullSealed, row.key_id, critical, deviceStrings);
  for (const candidate of fallbacks) {
    if (payloadBytes(payload) <= PUSH_BUDGET_BYTES) break;
    const sealed = await seal(row.encryption_public_key, 'content', JSON.stringify(candidate));
    payload = pushPayload(messageId, sealed, row.key_id, critical, deviceStrings);
  }

  // The wake waits for the push on purpose: it carries whether APNs accepted
  // this message, and that is what lets the app decide deterministically
  // whether to post its own banner instead of racing the push on a timer.
  const pushed = await push(
    c.env,
    c.env.DB,
    { id: row.device_id, apns_token: row.apns_token },
    payload,
    expiresAt,
    nowS,
    String(messageId),
  );
  const wake = (async () => {
    try {
      const id = c.env.DEVICE_SOCKET.idFromName(String(row.device_id));
      await c.env.DEVICE_SOCKET.get(id).notify(deviceSeq, pushed);
    } catch {
    }
  })();
  c.executionCtx.waitUntil(wake);

  if (asked && !critical) warnings.push(t(c).api.criticalNotAllowed);

  return c.json(
    warnings.length > 0 ? { ok: true as const, warnings } : { ok: true as const },
    202,
  );
});
