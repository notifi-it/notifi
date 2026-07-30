import type { Env } from '../types.js';
import { fromB64, fromHex, toB64 } from './bytes.js';

let cachedKey: CryptoKey | null = null;

async function aesKey(env: Env): Promise<CryptoKey> {
  if (cachedKey) return cachedKey;
  const raw = fromHex(env.ENCRYPTION_KEY);
  cachedKey = await crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, [
    'encrypt',
    'decrypt',
  ]);
  return cachedKey;
}

export async function encryptField(env: Env, plaintext: string): Promise<string> {
  const key = await aesKey(env);
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, new TextEncoder().encode(plaintext)),
  );
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv, 0);
  out.set(ct, iv.length);
  return toB64(out);
}

export async function decryptField(env: Env, stored: string): Promise<string> {
  const key = await aesKey(env);
  const blob = fromB64(stored);
  const iv = blob.subarray(0, 12);
  const ct = blob.subarray(12);
  const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct);
  return new TextDecoder().decode(pt);
}

export async function encryptPadded(env: Env, plaintext: string): Promise<string> {
  return encryptField(env, plaintext.padEnd(16, ' ').slice(0, 16));
}

export async function tokenHmacHex(env: Env, tokenHex: string): Promise<string> {
  const raw = fromHex(env.ENCRYPTION_KEY);
  const key = await crypto.subtle.importKey('raw', raw, { name: 'HMAC', hash: 'SHA-256' }, false, [
    'sign',
  ]);
  const mac = new Uint8Array(
    await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(tokenHex)),
  );
  let out = '';
  for (let i = 0; i < mac.length; i++) out += mac[i]!.toString(16).padStart(2, '0');
  return out;
}
