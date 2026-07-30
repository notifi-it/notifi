import { b64urlBytes, toHex } from './bytes.js';

export interface GeneratedKey {
  key: string;
  prefix: string;
  secretHash: string;
}

export async function generateSendKey(): Promise<GeneratedKey> {
  const random = crypto.getRandomValues(new Uint8Array(32));
  const body = b64urlBytes(random);
  const key = `nk_${body}`;
  const prefix = `nk_${body.slice(0, 4)}`;
  const secretHash = await hashKey(key);
  return { key, prefix, secretHash };
}

export async function hashKey(key: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  return toHex(digest);
}
