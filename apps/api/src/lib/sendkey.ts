import { b64urlBytes, toHex } from './bytes.js';

export interface GeneratedKey {
  key: string;
  prefix: string;
  secretHash: string;
}

const KEY_PREFIX = 'nk_';
const PREFIX_BODY_CHARS = 4;

export function keyPrefix(key: string): string {
  return key.slice(0, KEY_PREFIX.length + PREFIX_BODY_CHARS);
}

export async function generateSendKey(): Promise<GeneratedKey> {
  const random = crypto.getRandomValues(new Uint8Array(32));
  const body = b64urlBytes(random);
  const key = `${KEY_PREFIX}${body}`;
  const secretHash = await hashKey(key);
  return { key, prefix: keyPrefix(key), secretHash };
}

export async function hashKey(key: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  return toHex(digest);
}
