# Frequently asked questions

> What notifi costs, its limits, what our server can read, and what happens when you delete the app.

## The basics

### What is notifi?

A push-notification relay. One HTTP request to notifi.it and it’s on your iPhone or Mac. Nothing to install on the sending side, nothing to sign up for.

### What does it cost?

Nothing. There is no paid tier.

### Do I need an account?

No. The app makes a keypair on first launch. That is your identity. No signup required.

### How do I send something?

One request, `GET` or `POST`, JSON or form-encoded:

```
curl -X POST https://notifi.it/send \
  -H "Authorization: Bearer $NOTIFI_KEY" \
  -d "title=Hello from notifi" \
  -d "message=Your first notification." \
  -d "link=https://notifi.it/docs" \
  -d "image=https://notifi.it/anaglyph-bell.png"
```

A successful send answers `202` with `{"ok":true}`. The key can also be passed as a `key` parameter, though the [note on query strings](https://notifi.it/faq#logs) below applies if you do.

## Limits

### How much can I send?

- **25 notifications a day per device**, shared across its keys, reset at midnight UTC. Over that, `429` with `Retry-After`.
- **Five active keys per device**, including the device key.
- 100 requests a minute per IP on every endpoint.

### How long can a notification be?

- `title` — 1 to 200 characters, required.
- `message` — up to 16,000 characters.
- `link` and `image` — up to 2,048 characters.

Apple caps a push at 4,000 bytes, so a long notification is truncated in the banner and delivered in full to the app.

### Why did my send get a 401?

The key is unknown or revoked. Reinstalling the app or moving device makes a new identity and every old key stops working.

## Privacy and encryption

### Can you read my notifications?

No. Notifications are encrypted with your device’s public key before they are stored, and only your device can open them. See the [privacy policy](https://notifi.it/privacy).

### What can the server see?

Sender and device IP addresses, your platform and app version, the time of every send and collection, the rough size of each notification, which key sent it and how often, and your push token. See the [privacy policy](https://notifi.it/privacy).

### Is it safe to put the key in the URL?

It is the weaker option: a query string ends up in server logs. Ideally use an `Authorization: Bearer` header and a `POST` body. See the [docs](https://notifi.it/docs).

### How long are notifications kept?

A notification is deleted as soon as your device has it. An uncollected one waits, encrypted, with no time limit. Revoked keys are kept as hashes so they can never be reused.

### What happens if I delete the app?

Your notifications, keys and identity go with it. Nothing is recoverable, and every key stops working.

### Do you track me?

The apps have no analytics, crash reporting or tracking SDK, and this site sets no cookies. The server reports its own errors to Sentry and counts sends and collections, with no content and no IP address. See the [privacy policy](https://notifi.it/privacy).

## The apps

### Which devices does it run on?

iPhone and iPad on iOS 17+, Mac on macOS 14+, in the menu bar. No Android, because delivery goes through Apple’s push service.

### Where do I get the Mac app?

[Download the DMG](https://notifi.it/download/mac), which updates itself, or get it from the [Mac App Store](https://apps.apple.com/app/id1563961135?platform=mac). Same app.

### Can I send to more than one device?

Yes. Create a key on each. A key delivers only to the device that created it.

### How do I revoke a key?

In the app. The next send with it is refused. A key is shown once and never stored; if you lose it, make a new one.

## Urgent alerts

### What does the urgent toggle do?

A key marked urgent, sent with `is_critical=1`, is delivered as Time Sensitive: it breaks through Focus and stays on the lock screen.

### Will it ring through silent mode?

No. Time Sensitive breaks through Focus but respects the silent switch.

## Reliability

### Is delivery guaranteed?

No. Every send goes out over Apple’s push service and a websocket, and is stored before either, so the app can fetch what a push missed. Delivery still depends on Apple, your network and your device. See the [terms](https://notifi.it/terms).

> **Do not make notifi the only path for anything where a missed notification causes harm.** It is a pager for your own systems, not a life-safety, medical or emergency alerting system.

## Something else

Any questions please contact [hello@notifi.it](mailto:hello@notifi.it) or open an issue at [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues).

---

This page as HTML: https://notifi.it/faq

## More from notifi

- [Home](https://notifi.it/)
- [Docs](https://notifi.it/docs)
- [Privacy](https://notifi.it/privacy)
- [Terms](https://notifi.it/terms)
- [llms.txt](https://notifi.it/llms.txt)
- [hello@notifi.it](mailto:hello@notifi.it)
- [GitHub](https://github.com/notifi-it/notifi)
- [X](https://x.com/notifiit)
- [Instagram](https://instagram.com/notifidotit)
- [Facebook](https://facebook.com/notifidotit)
