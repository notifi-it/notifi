import { KEY_BYTES, KEY_PREFIX, keyPrefix } from '@notifi/contract';
import { b64urlBytes, toHex } from './bytes.js';

export interface GeneratedKey {
  key: string;
  prefix: string;
  secretHash: string;
}

const KEY_BODY_CHARS = Math.ceil((KEY_BYTES * 4) / 3);

export const SEND_KEY_PATTERN = new RegExp(`${KEY_PREFIX}[A-Za-z0-9_-]{${KEY_BODY_CHARS},}`, 'g');

export async function generateSendKey(): Promise<GeneratedKey> {
  const random = crypto.getRandomValues(new Uint8Array(KEY_BYTES));
  const key = `${KEY_PREFIX}${b64urlBytes(random)}`;
  const secretHash = await hashKey(key);
  return { key, prefix: keyPrefix(key), secretHash };
}

export async function hashKey(key: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(key));
  return toHex(digest);
}
