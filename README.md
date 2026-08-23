<p align="center">
  <img src="apps/api/public/anaglyph-bell.png" alt="notifi" width="140">
</p>

<p align="center"><b>Push notifications for your scripts, servers and side projects.</b></p>

Create a send key, send a title and body to `notifi.it` in one HTTP
request, and the notification lands on your iPhone or Mac.

```bash
curl "https://notifi.it/send?key=nk_…&title=hello+world"
```

No accounts. No sign-in. No device linking. The device holds the only private key,
notification content is encrypted with that key at ingest so the server cannot read it, and
each notification is deleted once the device acknowledges it. It is a relay, not a
mailbox.

The backend is a single Cloudflare Worker over a D1 database; the app is a
zero-dependency SwiftUI client for iOS 17+ and macOS 14+.

<p align="center">
  <img src="apps/app/fastlane/screenshots/en-GB/01_inbox.png" width="30%">
  <img src="apps/app/fastlane/screenshots/en-GB/02_message.png" width="30%">
  <img src="apps/app/fastlane/screenshots/en-GB/03_keys.png" width="30%">
</p>

## Documentation

- **[notifi API documentation](https://notifi.it/docs)** — the `/send` endpoint,
  its parameters, its error codes and its limits.
- **[llms.txt](https://notifi.it/llms.txt)** — the same thing as plain text for
  coding agents, including when to reach for notifi and how to ask a human for a
  send key.
- **[openapi.json](https://notifi.it/openapi.json)** — OpenAPI 3.1 for `/send`.
- **[Postman collection](https://notifi.it/notifi.postman_collection.json)** —
  v2.1, which Bruno, Insomnia and Hoppscotch import as well; the
  **[.bru file](https://notifi.it/notifi.bru)** is there for Bruno directly.
- **[FAQ](https://notifi.it/faq)**,
  **[privacy](https://notifi.it/privacy)**
  and **[terms](https://notifi.it/terms)**.

Every page of notifi.it is also served as Markdown: send `Accept: text/markdown`
to any page URL, or append `.md` to its path.

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
