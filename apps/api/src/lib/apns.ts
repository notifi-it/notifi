import type { DeviceRow, Env } from '../types.js';
import { b64url, b64urlBytes, pemToDer } from './bytes.js';
import { decryptField } from './fieldcrypto.js';

let cachedJwt: { jwt: string; mintedAt: number } | null = null;

async function providerJwt(env: Env, nowS: number): Promise<string> {
  if (cachedJwt && nowS - cachedJwt.mintedAt < 50 * 60) return cachedJwt.jwt;
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: env.APNS_KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: nowS }));
  const input = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(env.APNS_PRIVATE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(input),
  );
  cachedJwt = { jwt: `${input}.${b64urlBytes(new Uint8Array(sig))}`, mintedAt: nowS };
  return cachedJwt.jwt;
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
        // The collapse id becomes the delivered notification's request
        // identifier, so the app's own backstop banner — posted under the
        // same message id — and this push occupy one Notification Center
        // slot instead of two. Capped at 64 bytes by APNs.
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
      cachedJwt = null;
      try {
        res = await doSend();
      } catch (err) {
        console.error('apns.retry_failed', err, { host: env.APNS_HOST, device_id: device.id });
        return false;
      }
    }
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
