import type { Context, MiddlewareHandler } from 'hono';
import { errBody } from './lib/respond.js';
import { resolveDevice, verifyDeviceSignature } from './lib/signature.js';
import { LAST_SEEN_STALE_S, now } from './lib/time.js';
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
