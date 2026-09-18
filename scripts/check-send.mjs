#!/usr/bin/env node
// Exercises /send against a running local origin (`make dev`). Seeds its own
// devices and keys into the local D1 first, so it needs the same worktree's
// wrangler state. APNs is never reached: the seeded devices carry no token.
//
//   node scripts/check-send.mjs http://localhost:8787
//   SUITE=baseline node scripts/check-send.mjs http://localhost:8787
//   RECORD=1 node scripts/check-send.mjs http://localhost:8787   # print, don't assert
//
// Two suites. `baseline` pins the single-key contract: exact status and body
// for every documented outcome. `two-keys` covers a comma-separated pair.
// SUITE picks one; the default runs both. API_DIR points the seeding at
// another checkout's apps/api when the server under test runs from there.
// RECORD=1 prints one line per case and exits 0, for diffing across revisions.
import { webcrypto as crypto } from "node:crypto";
import { execFileSync } from "node:child_process";
import { writeFileSync, mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const base = (process.argv[2] ?? "http://localhost:8787").replace(/\/$/, "");
const record = process.env.RECORD === "1";
const suite = process.env.SUITE ?? "all";
const apiDir = process.env.API_DIR ?? new URL("../apps/api/", import.meta.url).pathname;

const PER_DEVICE_LIMIT = 60;
const WINDOW_S = 3600;
const TITLE_MAX = 200;
const MESSAGE_MAX = 16000;
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

async function send(label, { method = "POST", bearer, query, body, json, title = "check-send" }) {
  const url = new URL(`${base}/send`);
  if (query) url.searchParams.set("key", query);
  const headers = {};
  if (bearer) headers.Authorization = `Bearer ${bearer}`;
  let payload;
  if (method === "GET") {
    url.searchParams.set("title", title);
    for (const [k, v] of Object.entries(body ?? {})) url.searchParams.set(k, v);
  } else if (json) {
    headers["Content-Type"] = "application/json";
    payload = JSON.stringify({ title, ...json });
  } else {
    headers["Content-Type"] = "application/x-www-form-urlencoded";
    payload = new URLSearchParams({ title, ...(body ?? {}) }).toString();
  }
  const res = await fetch(url, { method, headers, body: payload });
  const text = await res.text();
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = text;
  }
  const retry = res.headers.get("retry-after");
  if (record) console.log(`${label} | ${res.status}${retry ? ` retry-after=${retry}` : ""} | ${text}`);
  return { status: res.status, body: parsed, retry, headers: res.headers };
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
function exact(label, r, status, body) {
  ok(`${label}: ${status}`, r.status === status, String(r.status));
  ok(`${label}: body`, json(r.body) === json(body), json(r.body));
}
const err = (code, message) => ({ error: { code, message } });
const UNKNOWN_KEY = err("unknown_key", "Unknown or revoked key.");
const INVALID_REQUEST = err("invalid_request", "Invalid send parameters.");
const INVALID_CONTENT = err(
  "invalid_content",
  "Not sent. This device is set to refuse a notification it cannot deliver as written.",
);
const RATE_LIMITED = err("rate_limited", "Rate limit exceeded. Too many notifications this hour.");
const TITLE_CROPPED = `Title shortened to ${TITLE_MAX} characters.`;
const MESSAGE_CROPPED = `Body shortened to ${MESSAGE_MAX} characters.`;
const CRITICAL_DOWNGRADED = "Sent as an ordinary notification: this key has no urgent alerts.";
const KEYS_INVALID = "Send to at most 2 keys, comma-separated, each on a different platform.";
const longTitle = "x".repeat(TITLE_MAX + 1);
const longMessage = "y".repeat(MESSAGE_MAX + 1);

let r;

if (suite === "baseline" || suite === "all") {
  r = await send("single bearer", { bearer: K.phone });
  exact("single bearer", r, 202, { ok: true });
  ok("single bearer: no-store", r.headers.get("cache-control") === "no-store", r.headers.get("cache-control") ?? "");
  ok("single bearer: CORS", r.headers.get("access-control-allow-origin") === "*", r.headers.get("access-control-allow-origin") ?? "");

  r = await send("single query", { query: K.mac });
  exact("single query", r, 202, { ok: true });

  r = await send("single body json", { json: { key: K.mac } });
  exact("single json body", r, 202, { ok: true });

  r = await send("single GET", { method: "GET", query: K.mac });
  exact("single GET", r, 202, { ok: true });

  r = await send("query beats bearer", { bearer: unknown, query: K.mac });
  exact("query beats bearer", r, 202, { ok: true });

  r = await send("no key", {});
  exact("no key", r, 400, INVALID_REQUEST);

  r = await send("no title", { bearer: K.phone, title: "" });
  exact("no title", r, 400, INVALID_REQUEST);

  r = await send("bad link", { bearer: K.phone, body: { link: "not a url" } });
  exact("bad link", r, 400, INVALID_REQUEST);

  r = await send("occurred_at in the future", { bearer: K.phone, json: { occurred_at: (nowS + 2 * 24 * 3600) * 1000 } });
  exact("occurred_at future", r, 400, err("invalid_request", "occurred_at is too far in the future."));

  r = await send("unknown", { bearer: unknown });
  exact("unknown", r, 401, UNKNOWN_KEY);

  r = await send("revoked", { bearer: K.revoked });
  exact("revoked", r, 401, UNKNOWN_KEY);

  r = await send("long title", { bearer: K.phone, title: longTitle });
  exact("long title", r, 202, { ok: true, warnings: [TITLE_CROPPED] });

  r = await send("long message", { bearer: K.phone, body: { message: longMessage } });
  exact("long message", r, 202, { ok: true, warnings: [MESSAGE_CROPPED] });

  r = await send("long title and message", { bearer: K.phone, title: longTitle, body: { message: longMessage } });
  exact("long both", r, 202, { ok: true, warnings: [TITLE_CROPPED, MESSAGE_CROPPED] });

  r = await send("strict long title", { bearer: K.strict, title: longTitle });
  exact("strict long title", r, 422, INVALID_CONTENT);

  r = await send("strict in bounds", { bearer: K.strict });
  exact("strict in bounds", r, 202, { ok: true });

  r = await send("limited alone", { bearer: K.limited });
  exact("limited", r, 429, RATE_LIMITED);
  ok("limited: Retry-After", r.retry !== null && Number(r.retry) > 0 && Number(r.retry) <= WINDOW_S, r.retry ?? "missing");

  r = await send("critical on plain key", { bearer: K.phone, body: { is_critical: "1" } });
  exact("critical on plain key", r, 202, { ok: true, warnings: [CRITICAL_DOWNGRADED] });

  r = await send("critical on strict key", { bearer: K.strict, body: { is_critical: "1" } });
  exact("critical on strict key", r, 422, INVALID_CONTENT);

  r = await send("critical off on plain key", { bearer: K.phone, body: { is_critical: "0" } });
  exact("critical off", r, 202, { ok: true });
}

if (suite === "two-keys" || suite === "all") {
  const prefixOf = (k) => (result) => k.startsWith(result.key) && result.key.length < k.length;

  r = await send("phone,mac bearer", { bearer: `${K.phone},${K.mac}` });
  ok("two: 202", r.status === 202, String(r.status));
  ok("two: ok, sent 2", r.body.ok === true && r.body.sent === 2, json(r.body));
  ok("two: both results ok", r.body.results?.length === 2 && r.body.results.every((x) => x.ok === true), json(r.body));
  ok("two: results named by key prefix, in order", prefixOf(K.phone)(r.body.results[0]) && prefixOf(K.mac)(r.body.results[1]), json(r.body));
  ok("two: no warnings", r.body.warnings === undefined, json(r.body));

  r = await send("mac,phone reversed", { bearer: `${K.mac},${K.phone}` });
  ok("reversed: order follows the list", prefixOf(K.mac)(r.body.results?.[0]) && prefixOf(K.phone)(r.body.results?.[1]), json(r.body));

  r = await send("phone,mac query", { query: `${K.phone},${K.mac}` });
  ok("two query: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

  r = await send("phone,mac json body", { json: { key: `${K.phone},${K.mac}` } });
  ok("two json: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

  r = await send("phone,mac GET", { method: "GET", query: `${K.phone},${K.mac}` });
  ok("two GET: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

  r = await send("phone, mac spaced", { bearer: `${K.phone}, ${K.mac}` });
  ok("two spaced: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));

  r = await send("phone,phone2 same platform", { bearer: `${K.phone},${K.phone2}` });
  exact("same platform", r, 400, err("invalid_request", KEYS_INVALID));

  r = await send("phone,phone duplicate", { bearer: `${K.phone},${K.phone}` });
  exact("duplicate", r, 400, err("invalid_request", KEYS_INVALID));

  r = await send("three keys", { bearer: `${K.phone},${K.mac},${K.strict}` });
  exact("three", r, 400, err("invalid_request", KEYS_INVALID));

  r = await send("empty segment", { bearer: `${K.phone},` });
  exact("empty segment", r, 400, err("invalid_request", KEYS_INVALID));

  r = await send("leading comma", { bearer: `,${K.phone}` });
  exact("leading comma", r, 400, err("invalid_request", KEYS_INVALID));

  r = await send("phone,revoked", { bearer: `${K.phone},${K.revoked}` });
  ok("one revoked: 202", r.status === 202, String(r.status));
  ok("one revoked: sent 1", r.body.sent === 1, json(r.body));
  ok("one revoked: first ok", r.body.results?.[0]?.ok === true, json(r.body));
  ok("one revoked: second unknown_key", json(r.body.results?.[1]?.error) === json(UNKNOWN_KEY.error), json(r.body));

  r = await send("revoked,unknown", { bearer: `${K.revoked},${unknown}` });
  exact("none live", r, 401, {
    ...UNKNOWN_KEY,
    sent: 0,
    results: [
      { key: r.body.results?.[0]?.key, ok: false, error: UNKNOWN_KEY.error },
      { key: r.body.results?.[1]?.key, ok: false, error: UNKNOWN_KEY.error },
    ],
  });

  r = await send("limited,mac", { bearer: `${K.limited},${K.mac}` });
  ok("one limited: 202", r.status === 202, String(r.status));
  ok("one limited: sent 1", r.body.sent === 1, json(r.body));
  ok("one limited: rate_limited result", json(r.body.results?.[0]?.error) === json(RATE_LIMITED.error), json(r.body));
  ok("one limited: mac ok", r.body.results?.[1]?.ok === true, json(r.body));
  ok("one limited: no Retry-After on 202", r.retry === null, r.retry ?? "");

  r = await send("limited,revoked", { bearer: `${K.limited},${K.revoked}` });
  ok("limited+revoked: first error's status", r.status === 429, String(r.status));
  ok("limited+revoked: first error's body", json(r.body.error) === json(RATE_LIMITED.error), json(r.body));
  ok("limited+revoked: Retry-After", r.retry !== null, "missing");

  r = await send("revoked,limited", { bearer: `${K.revoked},${K.limited}` });
  ok("revoked+limited: first error's status", r.status === 401, String(r.status));
  ok("revoked+limited: no Retry-After", r.retry === null, r.retry ?? "");

  r = await send("strict,mac long title", { bearer: `${K.strict},${K.mac}`, title: longTitle });
  ok("strict+mac: 202", r.status === 202, String(r.status));
  ok("strict+mac: strict refused", json(r.body.results?.[0]?.error) === json(INVALID_CONTENT.error), json(r.body));
  ok("strict+mac: mac sent with warning", r.body.results?.[1]?.ok === true && json(r.body.results[1].warnings) === json([TITLE_CROPPED]), json(r.body));
  ok("strict+mac: top-level warnings merged", json(r.body.warnings) === json([TITLE_CROPPED]), json(r.body));

  r = await send("phone,mac long title", { bearer: `${K.phone},${K.mac}`, title: longTitle });
  ok("both cropped: each result warns", r.body.results?.every((x) => json(x.warnings) === json([TITLE_CROPPED])), json(r.body));
  ok("both cropped: top-level deduplicated", json(r.body.warnings) === json([TITLE_CROPPED]), json(r.body));

  r = await send("phone,mac critical", { bearer: `${K.phone},${K.mac}`, body: { is_critical: "1" } });
  ok("both downgraded: sent 2", r.status === 202 && r.body.sent === 2, json(r.body));
  ok("both downgraded: one merged warning", json(r.body.warnings) === json([CRITICAL_DOWNGRADED]), json(r.body));

  r = await send("phone,unknown-form", { bearer: `${K.phone},nk_x` });
  ok("unknown second: 202 sent 1", r.status === 202 && r.body.sent === 1, json(r.body));
  ok("unknown second: prefix is the whole short key", r.body.results?.[1]?.key === "nk_x", json(r.body));
}

if (record) {
  process.exit(0);
}
if (failures > 0) {
  console.error(`${failures} of ${checks} checks failed against ${base}`);
  process.exit(1);
}
console.log(`${checks} checks passed against ${base}`);
