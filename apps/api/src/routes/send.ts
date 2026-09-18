import {
  MESSAGE_MAX,
  type MessageContent,
  OCCURRED_AT_MAX_SKEW_MS,
  type PublicErrorCode,
  SEND_KEYS_MAX,
  SEND_KEYS_SEPARATOR,
  type SendParams,
  type SendResponse,
  type SendResult,
  sendParams,
  TITLE_MAX,
  UNCOLLECTED_MAX,
} from '@notifi/contract';
import { copyFor, fmt, SOURCE_LANGUAGE, type Strings } from '@notifi/copy';
import { Hono } from 'hono';
import { push } from '../lib/apns.js';
import { errBody, t } from '../lib/respond.js';
import { seal } from '../lib/seal.js';
import { hashKey, keyPrefix } from '../lib/sendkey.js';
import {
  MESSAGE_BACKSTOP_S,
  now,
  PER_DEVICE_WINDOW_S,
  perDeviceLimit,
  windowStart,
} from '../lib/time.js';
import type { AppEnv } from '../types.js';
import type { Context } from 'hono';

const PUSH_BUDGET_BYTES = 4000;
const PREVIEW_MESSAGE_MAX = 1000;
const MINIMAL_MESSAGE_MAX = 200;

interface KeyDeviceRow {
  key_id: number;
  revoked_at: number | null;
  is_critical: number;
  device_id: number;
  seq_counter: number;
  acked_id: number;
  apns_token: string;
  apns_token_hmac: string;
  encryption_public_key: string;
  strict_send: number;
  platform: string;
}

interface Failure {
  status: 400 | 401 | 422 | 429;
  code: PublicErrorCode;
  message: string;
  retryAfter?: number;
}

interface Delivery {
  ok: true;
  warnings: string[];
}

function failure(status: Failure['status'], code: PublicErrorCode, message: string): Failure {
  return { status, code, message };
}

function parseKeys(raw: string): string[] | undefined {
  const keys = raw.split(SEND_KEYS_SEPARATOR).map((k) => k.trim());
  if (keys.length > SEND_KEYS_MAX) return undefined;
  if (keys.some((k) => k === '')) return undefined;
  if (new Set(keys).size !== keys.length) return undefined;
  return keys;
}

async function lookupKey(c: Context<AppEnv>, key: string): Promise<KeyDeviceRow | null> {
  const secretHash = await hashKey(key);
  return c.env.DB.prepare(
    `SELECT k.id AS key_id, k.revoked_at AS revoked_at, k.is_critical AS is_critical,
            d.id AS device_id, d.seq_counter AS seq_counter, d.acked_id AS acked_id,
            d.apns_token AS apns_token, d.apns_token_hmac AS apns_token_hmac,
            d.encryption_public_key AS encryption_public_key,
            d.strict_send AS strict_send, d.platform AS platform
     FROM keys k JOIN devices d ON d.id = k.device_id
     WHERE k.secret_hash = ?`,
  )
    .bind(secretHash)
    .first<KeyDeviceRow>();
}

function pushPayload(
  id: number,
  sealedB64: string,
  keyId: number,
  escalate: boolean,
  strings: Strings,
): object {
  const escalation = escalate
    ? { sound: 'default', 'interruption-level': 'time-sensitive' }
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

  const keys = parseKeys(input.key);
  if (!keys) {
    return c.json(
      errBody('invalid_request', fmt(t(c).api.invalidSendKeys, { max: SEND_KEYS_MAX })),
      400,
    );
  }

  const occurredAt = input.occurred_at;
  if (occurredAt !== undefined && occurredAt > nowS * 1000 + OCCURRED_AT_MAX_SKEW_MS) {
    return c.json(errBody('invalid_request', t(c).api.occurredAtTooFuture), 400);
  }

  const rows = await Promise.all(keys.map((key) => lookupKey(c, key)));
  const live = rows.filter((row): row is KeyDeviceRow => row !== null && row.revoked_at === null);
  if (new Set(live.map((row) => row.platform)).size !== live.length) {
    return c.json(
      errBody('invalid_request', fmt(t(c).api.invalidSendKeys, { max: SEND_KEYS_MAX })),
      400,
    );
  }

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

  const results: SendResult[] = [];
  const failures: Failure[] = [];
  for (const [i, key] of keys.entries()) {
    const row = rows[i];
    const outcome =
      row && row.revoked_at === null
        ? await deliver(c, row, { ...input, title, message }, warnings, nowS)
        : failure(401, 'unknown_key', t(c).api.unknownKey);
    if ('ok' in outcome) {
      results.push({
        key: keyPrefix(key),
        ok: true,
        ...(outcome.warnings.length > 0 ? { warnings: outcome.warnings } : {}),
      });
    } else {
      failures.push(outcome);
      results.push({
        key: keyPrefix(key),
        ok: false,
        error: { code: outcome.code, message: outcome.message },
      });
    }
  }

  const sent = results.length - failures.length;
  const fanout = results.length > 1 ? { sent, results } : {};
  const first = failures[0];
  if (first && sent === 0) {
    if (first.retryAfter !== undefined) c.header('Retry-After', String(first.retryAfter));
    return c.json({ ...errBody(first.code, first.message), ...fanout }, first.status);
  }
  const allWarnings = [...new Set(results.flatMap((r) => r.warnings ?? []))];
  const body: SendResponse = {
    ok: true,
    ...fanout,
    ...(allWarnings.length > 0 ? { warnings: allWarnings } : {}),
  };
  return c.json(body, 202);
});

async function deliver(
  c: Context<AppEnv>,
  row: KeyDeviceRow,
  input: SendParams,
  shared: string[],
  nowS: number,
): Promise<Delivery | Failure> {
  if (row.seq_counter - row.acked_id >= UNCOLLECTED_MAX) {
    return failure(429, 'uncollected_limit', t(c).api.uncollectedLimit);
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
    .bind(w, w, row.device_id, w, perDeviceLimit(c.env))
    .first<{ seq_counter: number }>();

  if (!allowed) {
    const still = await c.env.DB.prepare('SELECT id FROM devices WHERE id = ?')
      .bind(row.device_id)
      .first<{ id: number }>();
    if (!still) {
      return failure(401, 'unknown_key', t(c).api.unknownKey);
    }
    return {
      ...failure(429, 'rate_limited', t(c).api.rateLimitedAccount),
      retryAfter: w + PER_DEVICE_WINDOW_S - nowS,
    };
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
    return failure(401, 'unknown_key', t(c).api.unknownKey);
  }

  const createdAt = nowS;
  const occurredAt = input.occurred_at;
  const { title, message, image } = input;

  const critical = input.is_critical === true && row.is_critical === 1;
  const warnings = [...shared];
  if (input.is_critical === true && !critical) {
    warnings.push(t(c).api.criticalNotAllowed);
  }

  if (row.strict_send === 1 && warnings.length > 0) {
    return failure(422, 'invalid_content', t(c).api.strictContentRejected);
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

  const pushed = await push(
    c.env,
    c.env.DB,
    { id: row.device_id, apns_token: row.apns_token },
    payload,
    expiresAt,
    nowS,
    String(messageId),
  );
  const outcome =
    row.apns_token !== ''
      ? pushed
        ? 'pushed'
        : 'failed'
      : row.apns_token_hmac.startsWith('retired:')
        ? 'retired'
        : 'no-permission';
  c.env.SEND_EVENTS.writeDataPoint({
    indexes: [String(row.device_id)],
    blobs: [String(row.key_id), outcome, critical ? 'critical' : 'normal'],
    doubles: [payloadBytes(payload)],
  });

  const wake = (async () => {
    try {
      const id = c.env.DEVICE_SOCKET.idFromName(String(row.device_id));
      await c.env.DEVICE_SOCKET.get(id).notify(deviceSeq, pushed);
    } catch {
    }
  })();
  c.executionCtx.waitUntil(wake);

  return { ok: true, warnings };
}
