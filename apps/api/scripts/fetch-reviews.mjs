import { createPrivateKey, sign } from 'node:crypto';
import { writeFileSync } from 'node:fs';

const APP_ID = '1563961135';
const API = 'https://api.appstoreconnect.apple.com';
const MAX_PAGES = 5;

const issuerId = process.env.ASC_ISSUER_ID;
const keyId = process.env.ASC_KEY_ID;
const p8 = process.env.ASC_PRIVATE_KEY;
if (!issuerId || !keyId || !p8) {
  console.error('ASC_ISSUER_ID, ASC_KEY_ID and ASC_PRIVATE_KEY must be set.');
  process.exit(1);
}

const b64url = (input) =>
  Buffer.from(input).toString('base64').replace(/=+$/, '').replace(/\+/g, '-').replace(/\//g, '_');

function token() {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }));
  const payload = b64url(
    JSON.stringify({ iss: issuerId, iat: now, exp: now + 600, aud: 'appstoreconnect-v1' }),
  );
  const signature = sign('sha256', Buffer.from(`${header}.${payload}`), {
    key: createPrivateKey(p8),
    dsaEncoding: 'ieee-p1363',
  });
  return `${header}.${payload}.${b64url(signature)}`;
}

const jwt = token();
const reviews = [];
let url = `${API}/v1/apps/${APP_ID}/customerReviews?limit=200&sort=-createdDate`;

for (let page = 0; url && page < MAX_PAGES; page++) {
  const res = await fetch(url, { headers: { authorization: `Bearer ${jwt}` } });
  if (!res.ok) {
    console.error(`ASC answered ${res.status} for ${url}`);
    console.error(await res.text());
    process.exit(1);
  }
  const body = await res.json();
  for (const item of body.data ?? []) {
    const a = item.attributes ?? {};
    if (!item.id || !a.createdDate || !Number.isInteger(a.rating)) continue;
    reviews.push({
      id: item.id,
      rating: a.rating,
      title: a.title ?? '',
      body: a.body ?? '',
      author: a.reviewerNickname ?? '',
      country: (a.territory ?? '').toLowerCase(),
      date: a.createdDate,
    });
  }
  url = body.links?.next ?? null;
}

if (reviews.length === 0) {
  console.error('ASC returned no reviews; refusing to write SQL that empties the table.');
  process.exit(1);
}

const q = (s) => `'${String(s).replace(/\0/g, '').replace(/'/g, "''")}'`;
const nowS = Math.floor(Date.now() / 1000);

const lines = ['DELETE FROM app_reviews;'];
for (const r of reviews) {
  lines.push(
    `INSERT INTO app_reviews (id, rating, title, body, author, country, version, updated_at, fetched_at) VALUES (` +
      `${q(r.id)}, ${r.rating}, ${q(r.title)}, ${q(r.body)}, ${q(r.author)}, ${q(r.country)}, '', ${q(r.date)}, ${nowS});`,
  );
}

process.stdout.write(`${lines.join('\n')}\n`);
if (process.env.REVIEWS_JSON) {
  writeFileSync(process.env.REVIEWS_JSON, JSON.stringify(reviews));
}
console.error(`${reviews.length} reviews fetched.`);
