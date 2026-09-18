#!/usr/bin/env node
// Exercises /send against a running local origin (`make dev`): one key, two
// comma-separated keys, and every way the list can be wrong. Seeds its own
// devices and keys into the local D1 first, so it needs the same worktree's
// wrangler state. APNs is never reached: the seeded devices carry no token.
//
//   node scripts/check-send.mjs http://localhost:8787
//   RECORD=1 node scripts/check-send.mjs http://localhost:8787   # print, don't assert
//
// API_DIR points the seeding at another checkout's apps/api when the server
// under test runs from there.
//
// RECORD=1 prints one line per case (status, Retry-After, body) and exits 0, so
// the same run on two revisions can be diffed for a before/after.
import { webcrypto as crypto } from "node:crypto";
import { execFileSync } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const base = (process.argv[2] ?? "http://localhost:8787").replace(/\/$/, "");
const record = process.env.RECORD === "1";
const apiDir = process.env.API_DIR ?? new URL("../apps/api/", import.meta.url).pathname;

const PER_DEVICE_LIMIT = 60;
const WINDOW_S = 3600;
const TITLE_MAX = 200;
const nowS = Math.floor(Date.now() / 1000);
const windowStart = Math.floor(nowS / WINDOW_S) * WINDOW_S;
const run = crypto.getRandomValues(new Uint8Array(4)).join("");

async function p256PublicKeyB64() {
  const pair = await crypto.subtle.generateKey({ name: "ECDH", namedCurve: "P-256" }, true, ["deriveBits"]);
  const raw = await crypto.subtle.exportKey("raw", pair.publicKey);
  return Buffer.from(raw).toString("base64");
}

async function sha256hex(s) {
  const h = new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(s)));
  return [...h].map((x) => x.toString(16).padStart(2, "0")).join("");
}

function secret() {
  return `nk_${Buffer.from(crypto.getRandomValues(new Uint8Array(32))).toString("base64url")}`;
}

const devices = {
  phone: { platform: "ios" },
  phone2: { platform: "ios" },
  strict: { platform: "ios", strict_send: 1 },
  limited: { platform: "ios", rl_window_start: windowStart, rl_window_count: PER_DEVICE_LIMIT },
  mac: { platform: "macos" },
};
const keys = {
  phone: { device: "phone" },
  phone2: { device: "phone2" },
  strict: { device: "strict" },
  limited: { device: "limited" },
  mac: { device: "mac" },
  revoked: { device: "mac", revoked_at: nowS },
};

let sql = "";
for (const [name, d] of Object.entries(devices)) {
  d.public_key = `check-send-${run}-${name}`;
  d.encryption_public_key = await p256PublicKeyB64();
  sql += `INSERT INTO devices (public_key, encryption_public_key, apns_token, apns_token_hmac, platform, app_version, created_at, last_seen_at, strict_send, rl_window_start, rl_window_count)
    VALUES ('${d.public_key}', '${d.encryption_public_key}', '', 'retired:${d.public_key}', '${d.platform}', 'check', ${nowS}, ${nowS}, ${d.strict_send ?? 0}, ${d.rl_window_start ?? 0}, ${d.rl_window_count ?? 0});\n`;
}
for (const [name, k] of Object.entries(keys)) {
  k.secret = secret();
  const hash = await sha256hex(k.secret);
  sql += `INSERT INTO keys (device_id, meta_sealed, secret_hash, sent_count, rl_window_start, rl_window_count, created_at, revoked_at)
    SELECT id, '', '${hash}', 0, 0, 0, ${nowS}, ${k.revoked_at ?? "NULL"} FROM devices WHERE public_key = '${devices[k.device].public_key}';\n`;
}
const seedFile = join(mkdtempSync(join(tmpdir(), "notifi-check-send-")), "seed.sql");
writeFileSync(seedFile, sql);
execFileSync("pnpm", ["wrangler", "d1", "execute", "notifi-prod", "--local", "--file", seedFile], {
  cwd: apiDir,
  stdio: "ignore",
});

const K = Object.fromEntries(Object.entries(keys).map(([n, k]) => [n, k.secret]));
const unknown = secret();

async function send(label, { bearer, query, body, json, title = "check-send" }) {
  const url = new URL(`${base}/send`);
  if (query) url.searchParams.set("key", query);
  const headers = {};
  if (bearer) headers.Authorization = `Bearer ${bearer}`;
  let payload;
  if (json) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify({ title, ...json });
  } else {
    headers["Content-Type"] = "application/x-www-form-urlencoded";
    payload = new URLSearchParams({ title, ...(body ?? {}) }).toString();
  }
  const res = await fetch(url, { method: "POST", headers, body: payload });
  const text = await res.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  const retry = res.headers.get("retry-after");
  if (record) console.log(`${label} | ${res.status}${retry ? ` retry-after=${retry}` : ""} | ${text}`);
  return { status: res.status, body: parsed, retry };
}

let failures = 0;
let checks = 0;
function ok(label, condition, detail) {
  checks++;
  if (condition || record) return;
  failures++;
  console.error(`FAIL ${label}${detail ? ` — ${detail}` : ""}`);
}
const json = (v) => JSON.stringify(v);
const longTitle = "x".repeat(TITLE_MAX + 1);

let r;

r = await send("single bearer", { bearer: K.phone });
ok("single: 202", r.status === 202, String(r.status));
ok("single: ok", r.body.ok === true, json(r.body));
ok("single: exactly {ok:true}", json(r.body) === json({ ok: true }), json(r.body));

r = await send("single query", { query: K.mac });
ok("single query: 202", r.status === 202, String(r.status));

r = await send("single body json", { json: { key: K.mac } });
ok("single json body: 202", r.status === 202, String(r.status));

r = await send("unknown", { bearer: unknown });
ok("unknown: 401", r.status === 401, String(r.status));
ok("unknown: error shape only", Object.keys(r.body).join() === "error" && r.body.error.code === "unknown_key", json(r.body));

r = await send("revoked", { bearer: K.revoked });
ok("revoked: 401", r.status === 401, String(r.status));

r = await send("long title", { bearer: K.phone, title: longTitle });
ok("long title: 202", r.status === 202, String(r.status));
ok("long title: warning only", Object.keys(r.body).sort().join() === "ok,warnings" && r.body.warnings.length === 1, json(r.body));

r = await send("strict long title", { bearer: K.strict, title: longTitle });
ok("strict: 422", r.status === 422, String(r.status));
ok("strict: code", r.body.error?.code === "invalid_content", json(r.body));

r = await send("critical on plain key", { bearer: K.phone, body: { is_critical: "1" } });
ok("critical downgrade: 202", r.status === 202, String(r.status));
ok("critical downgrade: warning", r.body.warnings?.length === 1, json(r.body));

r = await send("critical on strict key", { bearer: K.strict, body: { is_critical: "1" } });
ok("critical strict: 422", r.status === 422, String(r.status));

r = await send("limited alone", { bearer: K.limited });
ok("limited: 429", r.status === 429, String(r.status));
ok("limited: Retry-After", r.retry !== null, "missing");
ok("limited: code", r.body.error?.code === "rate_limited", json(r.body));

r = await send("phone,mac bearer", { bearer: `${K.phone},${K.mac}` });
ok("two: 202", r.status === 202, String(r.status));
ok("two: sent 2", r.body.sent === 2, json(r.body));
ok("two: both ok", r.body.results?.every((x) => x.ok) && r.body.results.length === 2, json(r.body));
ok(
  "two: results named by a prefix of each key",
  K.phone.startsWith(r.body.results[0].key) && r.body.results[0].key.length < K.phone.length && K.mac.startsWith(r.body.results[1].key),
  json(r.body),
);

r = await send("phone,mac query", { query: `${K.phone},${K.mac}` });
ok("two query: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

r = await send("phone,mac json body", { json: { key: `${K.phone},${K.mac}` } });
ok("two json: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

r = await send("phone, mac spaced", { bearer: `${K.phone}, ${K.mac}` });
ok("two spaced: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

r = await send("phone,phone2 same platform", { bearer: `${K.phone},${K.phone2}` });
ok("same platform: 400", r.status === 400, String(r.status));
ok("same platform: code", r.body.error?.code === "invalid_request", json(r.body));

r = await send("phone,phone duplicate", { bearer: `${K.phone},${K.phone}` });
ok("duplicate: 400", r.status === 400, String(r.status));

r = await send("three keys", { bearer: `${K.phone},${K.mac},${K.strict}` });
ok("three: 400", r.status === 400, String(r.status));

r = await send("empty segment", { bearer: `${K.phone},` });
ok("empty segment: 400", r.status === 400, String(r.status));

r = await send("phone,revoked", { bearer: `${K.phone},${K.revoked}` });
ok("one revoked: 202", r.status === 202, String(r.status));
ok("one revoked: sent 1", r.body.sent === 1, json(r.body));
ok("one revoked: second result is unknown_key", r.body.results?.[1]?.ok === false && r.body.results[1].error?.code === "unknown_key", json(r.body));

r = await send("revoked,unknown", { bearer: `${K.revoked},${unknown}` });
ok("none live: 401", r.status === 401, String(r.status));
ok("none live: sent 0", r.body.sent === 0 && r.body.results?.length === 2, json(r.body));

r = await send("limited,mac", { bearer: `${K.limited},${K.mac}` });
ok("one limited: 202", r.status === 202, String(r.status));
ok("one limited: sent 1", r.body.sent === 1, json(r.body));
ok("one limited: rate_limited result", r.body.results?.[0]?.error?.code === "rate_limited", json(r.body));
ok("one limited: no Retry-After on 202", r.retry === null, r.retry ?? "");

r = await send("strict,mac long title", { bearer: `${K.strict},${K.mac}`, title: longTitle });
ok("strict+mac: 202", r.status === 202, String(r.status));
ok("strict+mac: strict refused, mac sent", r.body.results?.[0]?.error?.code === "invalid_content" && r.body.results?.[1]?.ok === true, json(r.body));
ok("strict+mac: top-level warning from mac", r.body.warnings?.length === 1, json(r.body));

if (record) {
  process.exit(0);
}
if (failures > 0) {
  console.error(`${failures} of ${checks} checks failed against ${base}`);
  process.exit(1);
}
console.log(`${checks} checks passed against ${base}`);
