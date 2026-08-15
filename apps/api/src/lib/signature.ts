import type { DeviceRow, Env } from '../types.js';
import { fromB64, toHex } from './bytes.js';
import { REPLAY_WINDOW_S } from './time.js';

export async function verifyDeviceSignature(
  req: Request,
  rawBody: ArrayBuffer,
  nowS: number,
): Promise<
  { ok: true; publicKey: string } | { ok: false; code: 'bad_signature' | 'stale_timestamp' }
> {
  const pk = req.headers.get('X-Notifi-Public-Key');
  const ts = req.headers.get('X-Notifi-Timestamp');
  const sig = req.headers.get('X-Notifi-Signature');
  if (!pk || !ts || !sig || !/^\d{1,12}$/.test(ts)) {
    return { ok: false, code: 'bad_signature' };
  }
  if (Math.abs(nowS - Number(ts)) > REPLAY_WINDOW_S) {
    return { ok: false, code: 'stale_timestamp' };
  }

  const url = new URL(req.url);
  const pathWithQuery = url.pathname + url.search;
  const bodyHashHex = toHex(await crypto.subtle.digest('SHA-256', rawBody));
  const canonical = [req.method, url.host.toLowerCase(), pathWithQuery, ts, bodyHashHex].join('\n');

  let key: CryptoKey;
  let sigBytes: Uint8Array;
  try {
    sigBytes = fromB64(sig);
    key = await crypto.subtle.importKey(
      'raw',
      fromB64(pk),
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify'],
    );
  } catch {
    return { ok: false, code: 'bad_signature' };
  }

  const ok = await crypto.subtle.verify(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    sigBytes,
    new TextEncoder().encode(canonical),
  );
  return ok ? { ok: true, publicKey: pk } : { ok: false, code: 'bad_signature' };
}

export async function resolveDevice(env: Env, publicKey: string): Promise<DeviceRow | null> {
  return env.DB.prepare('SELECT * FROM devices WHERE public_key = ?')
    .bind(publicKey)
    .first<DeviceRow>();
}
