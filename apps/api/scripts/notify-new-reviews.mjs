import { readFileSync } from 'node:fs';

const [, , existingPath, fetchedPath] = process.argv;
const key = process.env.NOTIFI_SEND_KEY;
if (!existingPath || !fetchedPath || !key) {
  console.error('usage: NOTIFI_SEND_KEY=nk_... node notify-new-reviews.mjs <existing.json> <fetched.json>');
  process.exit(1);
}

const existing = new Set(
  JSON.parse(readFileSync(existingPath, 'utf8'))
    .flatMap((r) => r.results ?? [])
    .map((row) => row.id),
);
const fetched = JSON.parse(readFileSync(fetchedPath, 'utf8'));
const fresh = fetched.filter((r) => !existing.has(r.id));

if (existing.size === 0 && fresh.length > 1) {
  console.error(`Table was empty; skipping ${fresh.length} pushes rather than flooding.`);
  process.exit(0);
}

for (const r of fresh) {
  const stars = '★'.repeat(r.rating) + '☆'.repeat(5 - r.rating);
  const res = await fetch('https://notifi.it/send', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      key,
      title: `${stars} App Store review`,
      message: `${r.title}\n${r.body}\n${r.author} · ${r.country.toUpperCase()}`,
      link: 'https://apps.apple.com/app/id1563961135',
    }),
  });
  console.error(`push ${r.id}: ${res.status}`);
  if (!res.ok) console.error(await res.text());
}

console.error(`${fresh.length} new review(s).`);
