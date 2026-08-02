import { webcrypto as crypto } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { Aes256Gcm, CipherSuite, DhkemP256HkdfSha256, HkdfSha256 } from '@hpke/core';

const [encPubB64, deviceId, baseArg] = process.argv.slice(2);
const base = Number(baseArg ?? 1);
const now = Math.floor(Date.now() / 1000);
const suite = new CipherSuite({
  kem: new DhkemP256HkdfSha256(),
  kdf: new HkdfSha256(),
  aead: new Aes256Gcm(),
});
const enc = new TextEncoder();

const pk = await suite.kem.deserializePublicKey(
  Uint8Array.from(Buffer.from(encPubB64, 'base64')).buffer,
);
async function seal(info, plaintext) {
  const ctx = await suite.createSenderContext({ recipientPublicKey: pk, info: enc.encode(info) });
  const ct = new Uint8Array(await ctx.seal(enc.encode(plaintext)));
  const e = new Uint8Array(ctx.enc);
  const out = new Uint8Array(e.length + ct.length);
  out.set(e, 0);
  out.set(ct, e.length);
  return Buffer.from(out).toString('base64');
}
async function sha256hex(s) {
  const h = new Uint8Array(await crypto.subtle.digest('SHA-256', enc.encode(s)));
  return [...h].map((x) => x.toString(16).padStart(2, '0')).join('');
}

function randomSecret(prefix) {
  const bytes = crypto.getRandomValues(new Uint8Array(24));
  return `${prefix}_${Buffer.from(bytes).toString('base64url')}`;
}

const keys = [
  { id: base + 0, name: 'Grafana', prefix: 'nk_graf', key: randomSecret('nk_graf') },
  { id: base + 1, name: 'Deploy Bot', prefix: 'nk_dply', key: randomSecret('nk_dply') },
  { id: base + 2, name: 'Mail', prefix: 'nk_mail', key: randomSecret('nk_mail') },
];

let sql = '';
const out = {};
for (const k of keys) {
  const meta = await seal('key_meta', JSON.stringify({ id: k.id, name: k.name, prefix: k.prefix }));
  const hash = await sha256hex(k.key);
  sql += `INSERT INTO keys (id, device_id, meta_sealed, secret_hash, sent_count, rl_window_start, rl_window_count, created_at) VALUES (${k.id}, ${deviceId}, '${meta}', '${hash}', 0, 0, 0, ${now});\n`;
  out[k.name] = k.key;
}
writeFileSync('/tmp/notifi-seed.sql', sql);
console.log(JSON.stringify(out));
