# Frequently asked questions

> What notifi costs, what the limits are, what the server can and cannot read, and what happens when you delete the app.

## The basics

### What is notifi?

A push-notification relay. You create a send key in the app, send an HTTP request to `notifi.it/send` with a title and a body, and the notification lands on your iPhone and Mac. There is nothing to install on the sending side and nothing to sign up for.

### What does it cost?

Nothing. The service is free and there is no paid tier.

### Do I need an account?

No. The app generates a keypair on first launch, and that keypair is your identity. There is no email address, no password, and no way to link two devices together.

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

- **60 sends an hour per device**, shared by every key on that device rather than counted per key. The hour is the last sixty minutes, not the clock hour. Over the limit answers `429` with a `Retry-After` header.
- **500 uncollected notifications per device**, again across every key. A device that hasn't been open for 500 notifications: new sends answer `507` until the app is opened again.
- **Five active send keys per device**, one of which is the app’s own default key.
- There is also a per-IP ceiling of 100 requests a minute on every endpoint.

### How long can a notification be?

- `title` — 1 to 200 characters, required.
- `message` — up to 16,000 characters.
- `link` and `image` — up to 2,048 characters.

A push payload has a 4,000-byte ceiling set by Apple, so a long notification is truncated in the banner and delivered in full to the app.

### Why did my send get a 401?

The key is unknown or revoked. Revocation takes effect on the next send. Reinstalling the app, or moving to a new phone, creates a new identity and the old keys stop working, and there is no migration.

## Privacy and encryption

### Can you read my notifications?

No. The title, body, link and image URL are encrypted with your device’s public key at the moment they arrive, before anything is written to the database, and only your device holds the key that opens them. A full copy of the database together with every server secret does not reveal the contents of a single notification. The [source](https://github.com/notifi-it/notifi) is public.

### What can the server see?

The IP addresses of the sender and the device, the time of every send and every collection, the approximate size of a notification, which key sent it and how often, and your device’s push token. Because the sender and the recipient both talk to the same server, that server is in a position to correlate the two. The [privacy policy](https://notifi.it/privacy) covers this in full.

### Is it safe to put the key in the URL?

It is the weaker option. A query string lands in Cloudflare’s edge logs, your shell history and any proxy in between, in the clear, before the encryption happens. Use it only for a quick test, and rotate the key afterwards. Send the key as a `Authorization: Bearer` header and the body in a `POST` body where you can.

### How long are notifications kept?

A notification's content is deleted as soon as your device confirms it has it; only the fact that one was sent, and when, stays for up to a day. One your device never collects stays, encrypted, until it does, for at most 90 days. Revoked send keys are kept forever, as hashes, so that a revoked key can never be reused.

### What happens if I delete the app?

Your notifications, your keys and your identity go with it. None of it is recoverable, and every send key you created stops working.

### Do you track me?

There is no analytics, no crash reporting, no advertising identifier and no tracking SDK in the apps. This website sets no cookies and serves its fonts from this domain; Cloudflare, which hosts it, counts visits with its cookieless Web Analytics, and that is the only analytics anywhere in the product. The [privacy policy](https://notifi.it/privacy) has the full picture.

## The apps

### Which devices does it run on?

iPhone and iPad on iOS 17 or later, and Mac on macOS 14 or later, where it lives in the menu bar. There is no Android app, because delivery goes through Apple’s push service.

### Where do I get the Mac app?

From this site, as a notarized DMG. It is not on the App Store, and it updates itself.

### Can I send to more than one device?

Yes, by creating a key on each. A key delivers only to the device that created it, so which key a script holds decides where its notifications land.

### How do I revoke a key?

Revoke it in the app. The next send with it is refused. A key is shown once when it is created and is never stored, so it cannot be shown again — if you lose it, make a new one.

## Urgent alerts

### What does the urgent toggle do?

A key marked urgent, sent with `is_critical=1`, is delivered as a Time Sensitive notification: it breaks through Focus and stays on the lock screen. It does **not** sound through the silent switch. Both halves are required — a send that asks for urgency with a key that does not have it is delivered as an ordinary notification rather than refused.

### Will it ever ring through silent mode?

That needs Apple’s Critical Alerts entitlement, which has been requested and not yet granted. If it is granted, the same toggle reaches the higher level with nothing else to change.

## Reliability

### Is delivery guaranteed?

No. Every send goes out over Apple’s push service and a websocket at the same time, and the notification is stored before either, so the app can fetch anything a push missed. But delivery still depends on Apple, your network and your device’s settings, and the service is provided as is, without an uptime guarantee. See the [terms](https://notifi.it/terms).

> **Do not make notifi the only path for anything where a missed notification causes harm.** It is a pager for your own systems, not a life-safety, medical or emergency alerting system.

## Something else

Questions not answered here can be raised at [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues).

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
