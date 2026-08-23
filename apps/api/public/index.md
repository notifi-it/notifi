# notifi: push notifications to iPhone and Mac from one request

> One HTTP request to notifi.it, and a native push notification lands on your
> iPhone, iPad or Mac. No account, no SDK. Notification content is encrypted
> with your public key, so neither we nor Apple can read your notifications.

If you are a coding agent, read [llms.txt](https://notifi.it/llms.txt) instead:
it is the same product with the install steps, the key handover script, the full
parameter list and the hook recipes, and nothing else.

## When to use notifi

Reach for notifi when a program you control needs to interrupt a person who is
not watching a terminal:

- A long build, backup, migration or training run has finished, or failed.
- A CI job or deploy broke and someone should look now rather than at standup.
- A coding agent has finished a task, or is blocked waiting on a decision.
- A cron job, home server or monitoring script noticed something — a disk
  filling, a certificate expiring, a service that stopped answering.
- A webhook you already receive should reach a phone as well as a log.

It is the wrong tool for notifying anyone who has not handed you one of their
own send keys, for marketing, and for anything where a missed notification
causes harm: a key delivers only to the device that made it, and delivery is
best-effort.

## Start

1. Install the app: [iPhone and iPad](https://apps.apple.com/app/id1563961135)
   (iOS 17 or later) or [Mac](https://notifi.it/download/mac) (macOS 14 or
   later, also `brew install --cask notifi-it/tap/notifi`).
2. Allow notifications when the app asks.
3. Open the Keys tab, pick `Default`, press **Copy key**. It starts with `nk_`.
4. Send something:

```
curl -X POST https://notifi.it/send \
  -H "Authorization: Bearer $NOTIFI_KEY" \
  -d "title=Hello from notifi" \
  -d "message=Your first notification." \
  -d "link=https://notifi.it/docs" \
  -d "image=https://notifi.it/anaglyph-bell.png"
```

`202` with `{"ok":true}` means the server took it.

## The API

One endpoint: `GET` or `POST https://notifi.it/send`, JSON or form-encoded.
Authenticate with `Authorization: Bearer nk_yourkey`, or pass `key` as a
parameter — the header keeps it out of logs.

- `key` — required unless sent as a bearer token. Picks the device that gets the notification.
- `title` — required, 1 to 200 characters.
- `message` — the body, Markdown, up to 16,000 characters.
- `link` — URL opened when the notification is tapped, up to 2,048 characters.
- `image` — `https` URL to a PNG, JPEG or GIF, 5 MB max.
- `occurred_at` — unix milliseconds, for a queued or retried send.
- `is_critical` — breaks through Focus, if the key allows it.

Errors nest the code one level down — read `error.code`, not `code`:
`invalid_request` (400), `unknown_key` (401), `invalid_content` (422),
`rate_limited` (429, with `Retry-After`). 60 notifications an hour per device,
shared across every key on it; five active keys per device.

The full reference is at [notifi.it/docs](https://notifi.it/docs), machine-readable
at [notifi.it/openapi.json](https://notifi.it/openapi.json).

## What it costs

Nothing. The service is free, there is no paid tier, and there is nothing to
sign up for. The app, the API and the cryptography are open source at
[github.com/notifi-it/notifi](https://github.com/notifi-it/notifi).

---

This page as HTML: https://notifi.it/

## More from notifi

- [Docs](https://notifi.it/docs)
- [FAQ](https://notifi.it/faq)
- [Privacy](https://notifi.it/privacy)
- [Terms](https://notifi.it/terms)
- Email: hello@notifi.it
- [llms.txt](https://notifi.it/llms.txt)
- [GitHub](https://github.com/notifi-it/notifi)
- [X](https://x.com/notifiit)
- [Instagram](https://instagram.com/notifidotit)
- [Facebook](https://facebook.com/notifidotit)
