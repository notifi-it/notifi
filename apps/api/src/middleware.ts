import type { Context, MiddlewareHandler } from 'hono';
import { errBody } from './lib/respond.js';
import { resolveDevice, verifyDeviceSignature } from './lib/signature.js';
import { toHex } from './lib/bytes.js';
import { LAST_SEEN_STALE_S, now, REPLAY_WINDOW_S } from './lib/time.js';
import type { AppEnv, DeviceRow, Env } from './types.js';

export const ipLimiter: MiddlewareHandler<AppEnv> = async (c, next) => {
  const ip = c.req.header('CF-Connecting-IP') ?? '';
  const { success } = await c.env.SEND_IP_LIMIT.limit({ key: ip });
  if (!success) {
    c.header('Retry-After', '60');
    return c.json(errBody('rate_limited', 'Too many requests from this IP.'), 429);
  }
  return next();
};

export const signatureAuth: MiddlewareHandler<AppEnv> = async (c, next) => {
  // At most once per request. `keys.ts` registers this on both `/keys` and
  // `/keys/*`, and Hono matches a request for `/keys` against both, so it ran
  // twice: the first pass consumed the signature and the second rejected the
  // same signature as a replay. Every signed request to /keys failed with
  // "Request signature has already been used", which reads like an attack being
  // blocked rather than the guard eating its own requests.
  //
  // Guarded here rather than by de-duplicating the route table, because the
  // failure mode of a missed registration is an unauthenticated endpoint.
  if (c.get('signatureChecked')) return next();

  const nowS = now();
  const rawBody = await c.req.arrayBuffer();
  const result = await verifyDeviceSignature(c.req.raw, rawBody, nowS);
  if (!result.ok) {
    const message =
      result.code === 'stale_timestamp'
        ? 'Request timestamp is outside the allowed window.'
        : 'Invalid request signature.';
    return c.json(errBody(result.code, message), 401);
  }
  const sigHeader = c.req.header('X-Notifi-Signature') ?? '';
  const sigHash = toHex(
    await crypto.subtle.digest('SHA-256', new TextEncoder().encode(sigHeader)),
  );
  const fresh = await c.env.DB.prepare(
    `INSERT INTO seen_signatures (sig_hash, expires_at) VALUES (?, ?)
     ON CONFLICT(sig_hash) DO NOTHING RETURNING sig_hash`,
  )
    .bind(sigHash, nowS + REPLAY_WINDOW_S)
    .first<{ sig_hash: string }>();
  if (!fresh) {
    return c.json(errBody('bad_signature', 'Request signature has already been used.'), 401);
  }

  c.set('signatureChecked', true);
  c.set('rawBody', rawBody);
  c.set('publicKey', result.publicKey);
  return next();
};

export async function getDevice(c: Context<AppEnv>): Promise<DeviceRow | null> {
  return resolveDevice(c.env, c.get('publicKey'));
}

export async function bumpLastSeenIfStale(
  env: Env,
  device: DeviceRow,
  nowS: number,
): Promise<void> {
  if (nowS - device.last_seen_at > LAST_SEEN_STALE_S) {
    await env.DB.prepare('UPDATE devices SET last_seen_at = ? WHERE id = ?')
      .bind(nowS, device.id)
      .run();
  }
}
