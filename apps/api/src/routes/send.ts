import {
  MESSAGE_MAX,
  type MessageContent,
  OCCURRED_AT_MAX_SKEW_MS,
  sendParams,
  TITLE_MAX,
  UNCOLLECTED_MAX,
} from '@notifi/contract';
import { copyFor, fmt, SOURCE_LANGUAGE, type Strings } from '@notifi/copy';
import { Hono } from 'hono';
import { push } from '../lib/apns.js';
import { errBody, t } from '../lib/respond.js';
import { encrypt } from '../lib/encrypt.js';
import {
  insertMessageWithinLimits,
  readSendLimitUsage,
  recordKeyUse,
} from '../lib/messages.js';
import { hashKey } from '../lib/sendkey.js';
import { MESSAGE_BACKSTOP_S, now, PER_DEVICE_WINDOW_S, perDeviceLimit } from '../lib/time.js';
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
  encryptedB64: string,
  keyId: number,
  shouldEscalate: boolean,
  strings: Strings,
): object {
  const escalation = shouldEscalate
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
    notifi: { id, sealed: encryptedB64 },
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
  const keyDevice = await c.env.DB.prepare(
    `SELECT k.id AS key_id, k.revoked_at AS revoked_at, k.is_critical AS is_critical,
            d.id AS device_id, d.apns_token AS apns_token,
            d.encryption_public_key AS encryption_public_key,
            d.strict_send AS strict_send
     FROM keys k JOIN devices d ON d.id = k.device_id
     WHERE k.secret_hash = ?`,
  )
    .bind(secretHash)
    .first<KeyDeviceRow>();

  if (!keyDevice || keyDevice.revoked_at !== null) {
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

  const isCriticalAsked = input.is_critical === true;
  const isCritical = isCriticalAsked && keyDevice.is_critical === 1;

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

  const image = input.image;

  if (keyDevice.strict_send === 1 && warnings.length > 0) {
    return c.json(errBody('invalid_content', t(c).api.strictContentRejected), 422);
  }

  const content: MessageContent = {
    title,
    ...(message !== undefined ? { message } : {}),
    ...(input.link !== undefined ? { link: input.link } : {}),
    ...(image !== undefined ? { image } : {}),
    key_id: keyDevice.key_id,
    created_at: createdAt,
    ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
    is_critical: isCritical,
  };
  const fullEncrypted = await encrypt(keyDevice.encryption_public_key, 'content', JSON.stringify(content));

  const expiresAt = nowS + MESSAGE_BACKSTOP_S;

  const hourStartS = nowS - PER_DEVICE_WINDOW_S;
  const messageId = await insertMessageWithinLimits(
    c.env.DB,
    {
      deviceId: keyDevice.device_id,
      keyId: keyDevice.key_id,
      contentEncrypted: fullEncrypted,
      createdAt,
      expiresAt,
      occurredAt: occurredAt ?? null,
    },
    { hourStartS, sendsPerHour: perDeviceLimit(c.env), uncollectedMax: UNCOLLECTED_MAX },
  );

  if (messageId === null) {
    const usage = await readSendLimitUsage(c.env.DB, keyDevice.device_id, hourStartS);
    if (usage && usage.uncollectedCount >= UNCOLLECTED_MAX) {
      console.error('send.uncollected_limit', {
        device_id: keyDevice.device_id,
        key_id: keyDevice.key_id,
        uncollected_count: usage.uncollectedCount,
        limit: UNCOLLECTED_MAX,
      });
      return c.json(
        errBody('too_many_uncollected', fmt(t(c).api.tooManyUncollected, { max: UNCOLLECTED_MAX })),
        507,
      );
    }
    if (usage && usage.oldestSendInHour !== null) {
      c.header('Retry-After', String(usage.oldestSendInHour + PER_DEVICE_WINDOW_S - nowS));
      return c.json(errBody('rate_limited', t(c).api.rateLimitedAccount), 429);
    }
    return c.json(errBody('internal_error', t(c).api.unexpected), 500);
  }

  await recordKeyUse(c.env.DB, keyDevice.key_id, nowS);

  const fallbacks: MessageContent[] = [
    {
      title,
      ...(message !== undefined ? { message: message.slice(0, PREVIEW_MESSAGE_MAX) } : {}),
      ...(image !== undefined ? { image } : {}),
      key_id: keyDevice.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
      is_critical: isCritical,
    },
    {
      title,
      ...(message !== undefined ? { message: message.slice(0, MINIMAL_MESSAGE_MAX) } : {}),
      key_id: keyDevice.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
      is_critical: isCritical,
    },
    {
      title,
      key_id: keyDevice.key_id,
      created_at: createdAt,
      ...(occurredAt !== undefined ? { occurred_at: occurredAt } : {}),
      is_critical: isCritical,
    },
  ];

  const deviceStrings = copyFor(SOURCE_LANGUAGE);

  let payload = pushPayload(messageId, fullEncrypted, keyDevice.key_id, isCritical, deviceStrings);
  for (const candidate of fallbacks) {
    if (payloadBytes(payload) <= PUSH_BUDGET_BYTES) break;
    const encrypted = await encrypt(keyDevice.encryption_public_key, 'content', JSON.stringify(candidate));
    payload = pushPayload(messageId, encrypted, keyDevice.key_id, isCritical, deviceStrings);
  }

  const wasPushed = await push(
    c.env,
    c.env.DB,
    { id: keyDevice.device_id, apns_token: keyDevice.apns_token },
    payload,
    expiresAt,
    nowS,
    String(messageId),
  );
  const wake = (async () => {
    try {
      const id = c.env.DEVICE_SOCKET.idFromName(String(keyDevice.device_id));
      await c.env.DEVICE_SOCKET.get(id).notify(messageId, wasPushed);
    } catch {
    }
  })();
  c.executionCtx.waitUntil(wake);

  if (isCriticalAsked && !isCritical) warnings.push(t(c).api.criticalNotAllowed);

  return c.json(
    warnings.length > 0 ? { ok: true as const, warnings } : { ok: true as const },
    202,
  );
});
