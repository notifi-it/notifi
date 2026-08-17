---
name: load-test
description: Load test the send path — the dev Worker, and the app under a flood of real pushes. Trigger with /load-test or when asked to load test, stress test, or find the throughput ceiling of the API.
---

# Load test the send path

Two halves, and they answer different questions. The Worker half asks how many
sends per second survive; the app half asks what a phone does when a thousand
of them land at once. Do both — a green server number says nothing about the
inbox.

Never point load at production. Everything below targets
`https://notifi-api-dev.maxisme.workers.dev`.

## The four ceilings, in the order they bite

You will hit these before you hit anything interesting, and each one looks like
a bug if you do not know it is there.

1. **Per-IP, 100/min in production, 10000/min in dev** (`SEND_IP_LIMIT` in
   `wrangler.toml`). Spoofing `CF-Connecting-IP` does **not** work — Cloudflare
   rejects the header at the edge with a 403 and `error code: 1000`, before the
   Worker runs. One machine, one limit.
2. **Per-device, 60/hour by default** (`PER_DEVICE_LIMIT`, dev sets 10000). It
   is per *device*, not per key, so minting twenty keys for one device buys you
   nothing. Twenty devices buys you twenty budgets.
3. **APNs.** Apple throttles a real device independently of anything here.
4. **D1 write latency**, which is the actual ceiling once the rest are lifted.

Both limits are already raised in dev's `wrangler.toml`. They only take effect
once something deploys, so `make deploy-dev` first or you are testing the old
numbers.

## Seeding

`/send` needs a key, and a key needs a device. Insert both straight into remote
D1 rather than registering apps:

```bash
cd apps/api
pnpm wrangler d1 execute notifi-dev --remote --file=/tmp/fleet.sql
```

Each row pair is one device (`platform`, `app_version`, `apns_token`,
`apns_token_hmac`, all non-null) and one key whose `secret_hash` is the
lowercase hex SHA-256 of the key string — the same hash `hashKey` computes, no
salt. Set `apns_token` to the empty string and `push()` returns early, so the
run measures the Worker without involving Apple.

**Two traps that have already cost time here:**

- **Ids.** `devices.id` is a plain integer primary key, so seeding id 99120
  drags the auto-assigned sequence up behind it: the next genuine registration
  lands on 99121 and a `DELETE ... BETWEEN` cleanup eats a real device. Delete
  by an explicit id list you captured at seed time, and check `public_key`
  looks like your placeholder before deleting anything.
- **`cd`.** Working directory resets between bash calls. `wrangler` only exists
  under `apps/api`, and a failed `cd` leaves the rest of the `&&` chain running
  somewhere else — `pnpm` then fails with `ERR_PNPM_RECURSIVE_EXEC_FIRST_FAIL`,
  which contains no lowercase "error" and slips past `grep -i error`. Grep for
  `Executed` on success instead of grepping for failure.

## Driving it

A plain Node script with N workers racing a deadline is enough; there is no
load tool installed and `oha`/`hey`/`wrk` are all absent. Spread requests
across the seeded keys, record status counts separately from latency, and
report the two apart — a fast p50 made entirely of 429s reads as success.

Sweep concurrency rather than picking one number. Locally the Worker plateaus
near 70 req/s at every concurrency from 1 to 50; deployed it climbs to roughly
130-140 req/s at 100-200 concurrent, and past that only latency moves.

## Watching the server side

`wrangler tail --format json` from `apps/api`, started *before* the run. Output
is pretty-printed, so split on `/\n(?=\{)/` rather than by line, or you will
parse zero events and conclude the run was clean.

What to read: `cpuTime` against `wallTime`. 2-3ms CPU under a 1s wall means the
Worker is waiting on D1, not computing, which is the honest description of this
service under load. `exceptions` catches the rest.

Sentry has both environments at full sampling, and it is the only place a
dropped push shows up — `/send` answers 202 whether or not APNs took it. Check
it after every run.

## The app half

A simulator gets a real APNs token on Apple silicon, so it exercises the true
path and costs nothing:

```bash
xcrun simctl create notifi-load com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro com.apple.CoreSimulator.SimRuntime.iOS-26-3
```

Boot it, build the Debug scheme (Debug points `API_BASE_URL` at the dev Worker),
install, launch, and accept the notification prompt — no device row appears in
D1 until permission is granted and iOS hands over a token. Then find the newest
`devices` row, mint a key against it, and burst.

A physical iPhone works too, over cable, and `xcrun devicectl` needs the id from
`xcodebuild -showdestinations` (`00008150-...`), not the one `devicectl list`
prints. But an app already registered keeps its keypair, so it reuses its
existing device row instead of creating one — look at `last_seen_at`, not for a
new id.

Verify by screenshot, and check the header count against what you sent: 1325
pushes at 40 concurrent arrived intact, in order, with no crash. Also worth a
`log stream --predicate 'process == "notifi"'` for anything the UI hides.

## Cleaning up

Delete seeded messages, then keys, then devices, in that order — the foreign
keys care. Re-select afterwards to prove the rows are gone. D1 Time Travel can
restore the whole database if a cleanup takes something it should not, but it
restores *everything*, so ask before using it.
