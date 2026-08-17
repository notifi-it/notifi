<p align="center">
  <img src="apps/api/public/wordmark.svg" alt="notifi" width="260">
</p>

<p align="center"><b>Push notifications for your scripts, servers and side projects.</b></p>

Create a send key, send a title and body to `notifi.it` in one HTTP
request, and the notification lands on your iPhone or Mac.

```bash
curl "https://notifi.it/send?key=nk_…&title=hello+world"
```

No accounts. No sign-in. No device linking. The device holds the only private key,
notification content is sealed to that key at ingest so the server cannot read it, and
each notification is deleted once the device acknowledges it. It is a relay, not a
mailbox.

The backend is a single Cloudflare Worker over a D1 database; the app is a
zero-dependency SwiftUI client for iOS 17+ and macOS 14+.

<p align="center">
  <img src="apps/app/fastlane/screenshots/en-GB/01_inbox.png" width="30%">
  <img src="apps/app/fastlane/screenshots/en-GB/02_message.png" width="30%">
  <img src="apps/app/fastlane/screenshots/en-GB/03_keys.png" width="30%">
</p>

## Quickstart

```bash
pnpm install
make migrate     # apply migrations to the local D1
make dev         # wrangler dev — local Worker + local D1, what Debug builds talk to
```

## Layout

```
apps/
  app/        Xcode project (iOS + macOS + two NSE targets)
  api/        Cloudflare Worker (Hono, TypeScript) — @notifi/api
packages/
  contract/   Zod schemas, the single source of truth — @notifi/contract
```

This project has **no automated tests and no code comments** by decision —
verification is by hand.
