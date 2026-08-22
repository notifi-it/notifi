---
path: /faq
eyebrow: FAQ
title: notifi: frequently asked questions
description: Answers about notifi: what it costs, what the rate limits are, what the server can read, which platforms it runs on, and what happens when you delete the app.
ogTitle: notifi: frequently asked questions
ogDescription: What it costs, what the limits are, what the server can read, and what it does not promise.
---
# Frequently asked questions

> What notifi costs, what the limits are, what the server can and cannot read, and what happens when you delete the app.

## The basics

### What is notifi?

A push-notification relay. You create a send key in the app, send an HTTP request to `notifi.it/send` with a title and a body, and the alert lands on your iPhone and Mac. There is no SDK to install and nothing to sign up for.

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
  -d "image=https://notifi.it/sad-logo.png"
```

A successful send answers `202` with `{"ok":true}`. The key can also be passed as a `key` parameter, though the [note on query strings](/faq#logs) below applies if you do.

## Limits

### How much can I send?

- **60 sends an hour per device**, shared by every key on that device rather than counted per key. Over the limit answers `429` with a `Retry-After` header.
- **Five active send keys per device**, one of which is the app's own default key.
- There is also a per-IP ceiling of 100 requests a minute on every endpoint.

### How long can a notification be?

- `title` — 1 to 200 characters, required.
- `message` — up to 16,000 characters.
- `link` and `image` — up to 2,048 characters. An `image` must be `https`, and PNG, JPEG or GIF up to 5 MB.

A push payload has a 4,000-byte ceiling set by Apple, so a long notification is truncated in the banner and delivered in full to the app.

### Why did my send get a 401?

The key is unknown or revoked. Revocation takes effect on the next send. Reinstalling the app, or moving to a new phone, creates a new identity and the old keys stop working — there is no migration, by design.

## Privacy and encryption

### Can you read my notifications?

No. The title, body, link and image URL are encrypted with your device's public key at the moment they arrive, before anything is written to the database, and only your device holds the key that opens them. A full copy of the database together with every server secret does not reveal the contents of a single notification. The [source](https://github.com/notifi-it/notifi) is public if you want to check that claim rather than take it.

### What can the server see?

The IP addresses of the sender and the device, the time of every send and every collection, the approximate size of a notification, which key sent it and how often, and your device's push token. Because the sender and the recipient both talk to the same server, that server is in a position to correlate the two. The [privacy policy](/privacy) covers this in full.

### Is it safe to put the key in the URL?

It is convenient and it is the weaker option. A query string lands in Cloudflare's edge logs, your shell history and any proxy in between, in the clear, before the encryption happens. Send the key as a `Authorization: Bearer` header and the body in a `POST` body where you can.

### How long are notifications kept?

A notification is deleted as soon as your device confirms it has it. One your device never collects stays, encrypted, until it does — there is no time limit. Revoked send keys are kept forever, as hashes, so that a revoked key can never be reused.

### What happens if I delete the app?

Your notifications, your keys and your identity go with it. None of it is recoverable, because nothing is held that could recover it, and every send key you created stops working.

### Do you track me?

There is no analytics, no crash reporting, no advertising identifier and no third-party SDK in the apps. This website sets no cookies and makes no third-party request; the fonts are served from this domain.

## The apps

### Which devices does it run on?

iPhone and iPad on iOS 17 or later, and Mac on macOS 14 or later, where it lives in the menu bar. There is no Android app: delivery goes through Apple's push service.

### Where do I get the Mac app?

From this site, as a notarized DMG. It is not on the App Store, and it updates itself.

### Can I send to more than one device?

Yes, by creating a key on each. A key delivers only to the device that created it, so which key a script holds decides where its alerts land.

### How do I revoke a key?

Delete it in the app. The next send with it is refused. A key is shown once when it is created and is never stored, so it cannot be shown again — if you lose it, make a new one.

## Urgent alerts

### What does the urgent toggle do?

A key marked urgent, sent with `is_critical=1`, is delivered as a Time Sensitive notification: it breaks through Focus and stays on the lock screen. It does **not** sound through the silent switch. Both halves are required — a send that asks for urgency with a key that does not have it is delivered as an ordinary notification rather than refused.

### Will it ever ring through silent mode?

That needs Apple's Critical Alerts entitlement, which has been requested and not yet granted. If it is granted, the same toggle reaches the higher level with nothing else to change.

## Reliability

### Is delivery guaranteed?

No. Every send goes out over Apple's push service and a websocket at the same time, and the notification is stored before either, so the app can fetch anything a push missed. But delivery still depends on Apple, your network and your device's settings, and the service is provided as is, without an uptime guarantee. The [terms](/terms) say so plainly.

> **Do not make notifi the only path for anything where a missed notification causes harm.** It is a pager for your own systems, not a life-safety, medical or emergency alerting system.

## Something else

Questions not answered here can be raised at [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues).
