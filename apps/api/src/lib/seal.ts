import { Aes256Gcm, CipherSuite, DhkemP256HkdfSha256, HkdfSha256 } from '@hpke/core';
import { fromB64, toB64 } from './bytes.js';

const suite = new CipherSuite({
  kem: new DhkemP256HkdfSha256(),
  kdf: new HkdfSha256(),
  aead: new Aes256Gcm(),
});

export async function seal(
  recipientPublicKeyB64: string,
  info: 'content' | 'key_meta',
  plaintext: string,
): Promise<string> {
  const raw = fromB64(recipientPublicKeyB64);
  const pk = await suite.kem.deserializePublicKey(
    raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength),
  );
  const ctx = await suite.createSenderContext({
    recipientPublicKey: pk,
    info: new TextEncoder().encode(info),
  });
  const ct = new Uint8Array(await ctx.seal(new TextEncoder().encode(plaintext)));
  const enc = new Uint8Array(ctx.enc);
  const out = new Uint8Array(enc.length + ct.length);
  out.set(enc, 0);
  out.set(ct, enc.length);
  return toB64(out);
}
