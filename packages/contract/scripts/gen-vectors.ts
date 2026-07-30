import { webcrypto } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Aes256Gcm, CipherSuite, DhkemP256HkdfSha256, HkdfSha256 } from '@hpke/core';

const subtle = (webcrypto as unknown as Crypto).subtle;

function toB64(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('base64');
}
function fromB64url(s: string): Uint8Array {
  return new Uint8Array(Buffer.from(s, 'base64url'));
}

const suite = new CipherSuite({
  kem: new DhkemP256HkdfSha256(),
  kdf: new HkdfSha256(),
  aead: new Aes256Gcm(),
});

async function makeSignatureVector() {
  const kp = (await subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, [
    'sign',
    'verify',
  ])) as CryptoKeyPair;

  const pkcs8 = new Uint8Array(await subtle.exportKey('pkcs8', kp.privateKey));
  const jwk = await subtle.exportKey('jwk', kp.privateKey);
  const scalar = fromB64url(jwk.d!);
  const pubRaw = new Uint8Array(await subtle.exportKey('raw', kp.publicKey));

  const canonical =
    'GET\nnotifi.it\n/history?since=41&limit=50\n1753833600\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

  const sig = new Uint8Array(
    await subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      kp.privateKey,
      new TextEncoder().encode(canonical),
    ),
  );

  return {
    private_key_raw_b64: toB64(scalar),
    private_key_pkcs8_b64: toB64(pkcs8),
    public_key_x963_b64: toB64(pubRaw),
    method: 'GET',
    host: 'notifi.it',
    path_with_query: '/history?since=41&limit=50',
    timestamp: 1753833600,
    body_b64: '',
    canonical_string: canonical,
    signature_b64: toB64(sig),
  };
}

async function makeSealedVector() {
  const kp = (await subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, [
    'deriveBits',
  ])) as CryptoKeyPair;

  const pubBuf = await subtle.exportKey('raw', kp.publicKey);
  const pubRaw = new Uint8Array(pubBuf);
  const jwk = await subtle.exportKey('jwk', kp.privateKey);
  const scalar = fromB64url(jwk.d!);
  const pkcs8 = new Uint8Array(await subtle.exportKey('pkcs8', kp.privateKey));

  const info = 'content';
  const plaintext = '{"title":"Deploy finished","message":"main → prod"}';

  const pk = await suite.kem.deserializePublicKey(pubBuf);
  const ctx = await suite.createSenderContext({
    recipientPublicKey: pk,
    info: new TextEncoder().encode(info),
  });
  const ct = new Uint8Array(await ctx.seal(new TextEncoder().encode(plaintext)));
  const enc = new Uint8Array(ctx.enc);
  const out = new Uint8Array(enc.length + ct.length);
  out.set(enc, 0);
  out.set(ct, enc.length);

  return {
    recipient_private_key_raw_b64: toB64(scalar),
    recipient_private_key_pkcs8_b64: toB64(pkcs8),
    recipient_public_key_x963_b64: toB64(pubRaw),
    info,
    plaintext,
    sealed_b64: toB64(out),
  };
}

async function main() {
  const here = dirname(fileURLToPath(import.meta.url));
  const fixturesDir = join(here, '..', 'fixtures');
  mkdirSync(fixturesDir, { recursive: true });

  const signature = await makeSignatureVector();
  const sealed = await makeSealedVector();

  writeFileSync(
    join(fixturesDir, 'signature-vector.json'),
    JSON.stringify(signature, null, 2) + '\n',
  );
  writeFileSync(join(fixturesDir, 'sealed-vector.json'), JSON.stringify(sealed, null, 2) + '\n');

  process.stdout.write('wrote fixtures/signature-vector.json and fixtures/sealed-vector.json\n');
}

main().catch((err) => {
  process.stderr.write(String(err) + '\n');
  process.exit(1);
});
