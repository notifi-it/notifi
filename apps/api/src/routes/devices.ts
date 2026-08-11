import { registerDeviceBody, updateDeviceSettingsBody } from '@notifi/contract';
import { Hono } from 'hono';
import { fromB64 } from '../lib/bytes.js';
import { encryptField, encryptPadded, tokenHmacHex } from '../lib/fieldcrypto.js';
import { errBody, t } from '../lib/respond.js';
import { now } from '../lib/time.js';
import { signatureAuth } from '../middleware.js';
import type { AppEnv } from '../types.js';

export const devices = new Hono<AppEnv>();

devices.use('/devices', signatureAuth);
devices.use('/devices/settings', signatureAuth);

devices.post('/devices', async (c) => {
  const nowS = now();
  const headerPk = c.get('publicKey');

  let parsed;
  try {
    const text = new TextDecoder().decode(c.get('rawBody'));
    parsed = registerDeviceBody.parse(JSON.parse(text));
  } catch {
    return c.json(errBody('invalid_request', t(c).api.invalidDeviceBody), 400);
  }

  if (parsed.public_key !== headerPk) {
    return c.json(errBody('invalid_request', t(c).api.publicKeyMismatch), 400);
  }

  try {
    await crypto.subtle.importKey(
      'raw',
      fromB64(parsed.encryption_public_key),
      { name: 'ECDH', namedCurve: 'P-256' },
      false,
      [],
    );
  } catch {
    return c.json(
      errBody('invalid_request', t(c).api.invalidEncryptionKey),
      400,
    );
  }

  const tokenHmac = await tokenHmacHex(c.env, parsed.apns_token);
  const apnsEnc = await encryptField(c.env, parsed.apns_token);
  const platformEnc = await encryptPadded(c.env, parsed.platform);
  const versionEnc = await encryptPadded(c.env, parsed.app_version);

  const retireOthers = c.env.DB.prepare(
    `UPDATE devices SET apns_token = '', apns_token_hmac = 'retired:' || id
     WHERE apns_token_hmac = ? AND public_key != ?`,
  ).bind(tokenHmac, parsed.public_key);

  const upsert = c.env.DB.prepare(
    `INSERT INTO devices
       (public_key, encryption_public_key, apns_token, apns_token_hmac, platform, app_version, created_at, last_seen_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(public_key) DO UPDATE SET
       encryption_public_key = excluded.encryption_public_key,
       apns_token            = excluded.apns_token,
       apns_token_hmac       = excluded.apns_token_hmac,
       platform              = excluded.platform,
       app_version           = excluded.app_version,
       last_seen_at          = excluded.last_seen_at
     RETURNING id, strict_send`,
  ).bind(
    parsed.public_key,
    parsed.encryption_public_key,
    apnsEnc,
    tokenHmac,
    platformEnc,
    versionEnc,
    nowS,
    nowS,
  );

  let row: { id: number; strict_send: number } | null = null;
  for (let attempt = 0; attempt < 2; attempt++) {
    await retireOthers.run();
    try {
      row = await upsert.first<{ id: number; strict_send: number }>();
      break;
    } catch (err) {
      if (attempt === 1) throw err;
    }
  }

  return c.json({ device_id: row!.id, strict_send: row!.strict_send }, 200);
});

// The app re-registers on every launch and reads the setting out of that
// response, so this is write-only on purpose — a GET would be a second way to
// learn the same thing and a second thing to keep in step.
devices.patch('/devices/settings', async (c) => {
  const publicKey = c.get('publicKey');

  let parsed;
  try {
    const text = new TextDecoder().decode(c.get('rawBody'));
    parsed = updateDeviceSettingsBody.parse(JSON.parse(text));
  } catch {
    return c.json(errBody('invalid_request', t(c).api.invalidDeviceSettingsBody), 400);
  }

  const updated = await c.env.DB.prepare(
    'UPDATE devices SET strict_send = ?, last_seen_at = ? WHERE public_key = ? RETURNING id',
  )
    .bind(parsed.strict_send ? 1 : 0, now(), publicKey)
    .first<{ id: number }>();

  if (!updated) {
    return c.json(errBody('unknown_device', t(c).api.unknownDevice), 401);
  }

  return c.body(null, 204);
});
