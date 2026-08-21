# notifi API documentation

> notifi has one endpoint and seven parameters. This page is the whole reference: how to authenticate, what to send, what comes back, and where the machine-readable versions live.

## Before you start

You need the app and a send key. Install notifi on [iPhone or iPad](https://apps.apple.com/app/id1563961135) or [on the Mac](https://notifi.it/download/mac), allow notifications, then open the Keys tab and copy the `Default` key the app made on first launch. A key starts with `nk_` and delivers only to the device that created it, so which key a script holds decides where its notifications land.

Keys are minted on the device by a request signed with a private key that never leaves it. There is no endpoint that creates one, which is also why a coding agent cannot create a key for you — it has to ask you for it. Keep the key in the environment rather than in a file that gets committed.

## Send a notification

`POST https://notifi.it/send`, JSON or form-encoded. `GET` works for a quick test. Authenticate with an `Authorization: Bearer nk_yourkey` header; a `key` parameter also works but puts the key in edge logs and shell history. Query parameters win over the body.

```
curl -X POST https://notifi.it/send \
  -H "Authorization: Bearer $NOTIFI_KEY" \
  -d "title=Backup complete" \
  -d "message=4.2 GB in 3m 11s"
```

## Parameters

- `key` — string, required unless sent as a bearer token. The send key from the app.
- `title` — string, required. 1 to 200 characters.
- `message` — string. The notification body, Markdown, up to 16,000 characters. The push shows a short preview; the app renders the full text.
- `link` — URL, up to 2,048 characters. Opened when the notification is tapped.
- `image` — `https` URL, up to 2,048 characters. PNG, JPEG or GIF, 5 MB max. One that cannot be fetched is dropped and the notification still arrives.
- `occurred_at` — integer, unix milliseconds. When the event actually happened, for a queued or retried send. Defaults to arrival time.
- `is_critical` — boolean. Breaks through Focus. The key must also have critical alerts switched on in the app, or an ordinary notification is delivered and the reply carries a `warnings` array.

## Responses

A successful send answers `202` with `{"ok":true}`. That means the server accepted it, not that it was delivered — delivery is best-effort, as the [terms](https://notifi.it/terms) describe.

Every error nests the code one level down, so read `error.code` and not `code`:

```
{"error":{"code":"unknown_key","message":"Unknown or revoked key."}}
```

- `invalid_request` — `400`. A parameter is missing or malformed.
- `unknown_key` — `401`. The key is unknown or has been revoked.
- `invalid_content` — `422`. The device is set to refuse a notification it cannot deliver as written.
- `rate_limited` — `429`, with a `Retry-After` header.
- `not_found` — `404`. No such path.
- `internal_error` — `500`.

## Limits

- 60 notifications an hour per device, shared across every key on it.
- Five active send keys per device, one of which is the app's own default.
- 100 requests a minute per IP address, across every endpoint.
- Revoking a key in the app takes effect on the next send. Reinstalling the app, or moving to a new device, makes a new identity and every old key stops working; there is no migration.

## Machine-readable resources

- [`/llms.txt`](https://notifi.it/llms.txt) — the full reference as plain text, written for coding agents: install, key, endpoint, error codes and hook recipes, with a section on when to reach for notifi.
- [`/openapi.json`](https://notifi.it/openapi.json) — an OpenAPI 3.1 description of `/send`, for generating a client or wiring notifi into a tool that reads specifications.
- [`/sitemap.xml`](https://notifi.it/sitemap.xml) and [`/robots.txt`](https://notifi.it/robots.txt).
- Every page on this site is also served as Markdown. Ask for it with an `Accept: text/markdown` header on the same URL, or append `.md` — this page is [`/docs.md`](https://notifi.it/docs.md).
- [Source](https://github.com/notifi-it/notifi) — the app, the API and the cryptography.

## Recipes

The [home page](https://notifi.it/#send) carries the same request in thirteen languages and runtimes, including a Claude Code hook, a GitHub Actions step, a systemd unit and a Kubernetes job. [llms.txt](https://notifi.it/llms.txt) carries the hook recipes as copyable text.

## Questions

The [FAQ](https://notifi.it/faq) covers cost, limits, what the server can read and what happens when you delete the app. Anything else goes to [contact](https://notifi.it/contact).

---

This page as HTML: https://notifi.it/docs

## More from notifi

- [Home](https://notifi.it/)
- [About](https://notifi.it/about)
- [FAQ](https://notifi.it/faq)
- [Privacy](https://notifi.it/privacy)
- [Terms](https://notifi.it/terms)
- [llms.txt](https://notifi.it/llms.txt)
- [Contact](https://notifi.it/contact)
- [GitHub](https://github.com/notifi-it/notifi)
- [X](https://x.com/notifiit)
- [Instagram](https://instagram.com/notifidotit)
- [Facebook](https://facebook.com/notifidotit)
