import { PROVIDER_TOKEN_TTL_S, type ProviderToken } from '../apnstoken.js';
import type { DeviceRow, Env } from '../types.js';
import { decryptField } from './fieldcrypto.js';

const RETRY_DELAY_MS = 500;

let cachedJwt: ProviderToken | null = null;

function tokenStub(env: Env) {
  return env.APNS_TOKEN.get(env.APNS_TOKEN.idFromName('provider'));
}

async function providerJwt(env: Env, nowS: number): Promise<string> {
  if (cachedJwt && nowS - cachedJwt.mintedAt < PROVIDER_TOKEN_TTL_S) return cachedJwt.jwt;
  cachedJwt = await tokenStub(env).current(nowS);
  return cachedJwt.jwt;
}

async function rotateProviderJwt(env: Env, nowS: number): Promise<void> {
  const staleMintedAt = cachedJwt?.mintedAt ?? 0;
  cachedJwt = await tokenStub(env).replace(staleMintedAt, nowS);
}

export async function push(
  env: Env,
  db: D1Database,
  device: Pick<DeviceRow, 'id' | 'apns_token'>,
  payload: object,
  expiresAt: number,
  nowS: number,
  collapseId: string,
): Promise<boolean> {
  if (device.apns_token === '') return false;

  let tokenHex: string;
  try {
    tokenHex = await decryptField(env, device.apns_token);
  } catch (err) {
    console.error('apns.decrypt_failed', err, { device_id: device.id });
    return false;
  }

  const doSend = async () =>
    fetch(`${env.APNS_HOST}/3/device/${tokenHex}`, {
      method: 'POST',
      headers: {
        authorization: `bearer ${await providerJwt(env, nowS)}`,
        'apns-topic': env.APNS_TOPIC,
        'apns-push-type': 'alert',
        'apns-priority': '10',
        'apns-expiration': String(expiresAt),
        'apns-collapse-id': collapseId,
      },
      body: JSON.stringify(payload),
    });

  let res: Response;
  try {
    res = await doSend();
  } catch (err) {
    console.error('apns.fetch_failed', err, { host: env.APNS_HOST, device_id: device.id });
    return false;
  }

  if (res.status === 200) return true;

  let reason: string | null = null;

  if (res.status === 403) {
    const body = (await res.json().catch(() => null)) as { reason?: string } | null;
    reason = body?.reason ?? null;
    if (body?.reason === 'ExpiredProviderToken') {
      await rotateProviderJwt(env, nowS);
      try {
        res = await doSend();
      } catch (err) {
        console.error('apns.retry_failed', err, { host: env.APNS_HOST, device_id: device.id });
        return false;
      }
    }
  }

  if (res.status === 429) {
    const body = (await res.json().catch(() => null)) as { reason?: string } | null;
    reason = body?.reason ?? null;
    await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS));
    try {
      res = await doSend();
    } catch (err) {
      console.error('apns.retry_failed', err, { host: env.APNS_HOST, device_id: device.id });
      return false;
    }
    if (res.status === 200) return true;
  }

  if (res.status === 410) {
    const body = (await res.json().catch(() => null)) as { timestamp?: number } | null;
    if (body?.timestamp) {
      await db
        .prepare('DELETE FROM devices WHERE id = ? AND last_seen_at < ?')
        .bind(device.id, Math.floor(body.timestamp / 1000))
        .run();
    }
    return false;
  }

  if (res.status !== 200) {
    if (reason === null) {
      const body = (await res.json().catch(() => null)) as { reason?: string } | null;
      reason = body?.reason ?? null;
    }
    console.error('apns.non_200', {
      status: res.status,
      reason: reason ?? 'none',
      host: env.APNS_HOST,
      device_id: device.id,
    });
    return false;
  }
  return true;
}
