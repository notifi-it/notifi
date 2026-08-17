import { webcrypto } from 'node:crypto';

const subtle = (webcrypto as unknown as Crypto).subtle;

const APNS_HOST = process.env.APNS_HOST ?? 'https://api.sandbox.push.apple.com';
const APNS_TOPIC = process.env.APNS_TOPIC ?? 'it.notifi.notifi';
const APNS_TEAM_ID = required('APNS_TEAM_ID');
const APNS_KEY_ID = required('APNS_KEY_ID');
const APNS_PRIVATE_KEY = required('APNS_PRIVATE_KEY');
const DEVICE_TOKEN = required('APNS_DEVICE_TOKEN');

function required(name: string): string {
  const value = process.env[name];
  if (!value) {
    process.stderr.write(`missing env ${name}\n`);
    process.exit(1);
  }
  return value;
}

function b64url(s: string): string {
  return Buffer.from(s).toString('base64url');
}
function b64urlBytes(bytes: Uint8Array): string {
  return Buffer.from(bytes).toString('base64url');
}
function pemToDer(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN [^-]+-----/g, '')
    .replace(/-----END [^-]+-----/g, '')
    .replace(/\s+/g, '');
  return new Uint8Array(Buffer.from(body, 'base64'));
}

async function mintJwt(nowS: number): Promise<string> {
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: APNS_KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: APNS_TEAM_ID, iat: nowS }));
  const input = `${header}.${claims}`;
  const key = await subtle.importKey(
    'pkcs8',
    pemToDer(APNS_PRIVATE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const sig = new Uint8Array(
    await subtle.sign({ name: 'ECDSA', hash: 'SHA-256' }, key, new TextEncoder().encode(input)),
  );
  return `${input}.${b64urlBytes(sig)}`;
}

async function main() {
  const nowS = Math.floor(Date.now() / 1000);
  const jwt = await mintJwt(nowS);

  const payload = {
    aps: {
      alert: { title: 'notifi', body: 'phase 0 push' },
      sound: 'default',
    },
  };

  const res = await fetch(`${APNS_HOST}/3/device/${DEVICE_TOKEN}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-topic': APNS_TOPIC,
      'apns-push-type': 'alert',
      'apns-priority': '10',
    },
    body: JSON.stringify(payload),
  });

  process.stdout.write(`status ${res.status}\n`);
  const text = await res.text();
  if (text) process.stdout.write(`${text}\n`);
  process.stdout.write(`apns-id ${res.headers.get('apns-id') ?? '-'}\n`);
}

main().catch((err) => {
  process.stderr.write(String(err) + '\n');
  process.exit(1);
});
