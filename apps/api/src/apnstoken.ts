import { DurableObject } from 'cloudflare:workers';
import { b64url, b64urlBytes, pemToDer } from './lib/bytes.js';
import type { Env } from './types.js';

export const PROVIDER_TOKEN_TTL_S = 50 * 60;

export interface ProviderToken {
  jwt: string;
  mintedAt: number;
}

async function mint(env: Env, nowS: number): Promise<ProviderToken> {
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
  return { jwt: `${input}.${b64urlBytes(new Uint8Array(sig))}`, mintedAt: nowS };
}

export class ApnsToken extends DurableObject<Env> {
  async current(nowS: number): Promise<ProviderToken> {
    const held = await this.ctx.storage.get<ProviderToken>('token');
    if (held && nowS - held.mintedAt < PROVIDER_TOKEN_TTL_S) return held;

    const minted = await mint(this.env, nowS);
    await this.ctx.storage.put('token', minted);
    return minted;
  }

  async replace(staleMintedAt: number, nowS: number): Promise<ProviderToken> {
    const held = await this.ctx.storage.get<ProviderToken>('token');
    if (held && held.mintedAt > staleMintedAt) return held;

    const minted = await mint(this.env, nowS);
    await this.ctx.storage.put('token', minted);
    return minted;
  }
}
