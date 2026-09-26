---
path: /faq
eyebrow: FAQ
title: notifi: frequently asked questions
description: What notifi costs, its limits, what our server can read, and what happens when you delete the app.
ogDescription: What notifi costs, its limits, what our server can read, and what happens when you delete the app.
---
# Frequently asked questions

> What notifi costs, its limits, what our server can read, and what happens when you delete the app.

## The basics

### What is notifi?

A push-notification relay. Send one HTTP request to notifi.it and a notification arrives on your iPhone or Mac. The sending side needs no install and no signup.

### What does it cost?

Nothing. There is no paid tier.

### Do I need an account?

No. The app makes a keypair on first launch, and that keypair is your identity.

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

A successful send answers `202` with `{"ok":true}`. You can also pass the key as a `key` parameter, but a query string ends up in server logs.

## Limits

### How much can I send?

- **25 notifications a day per device**, shared across its keys. The count resets at midnight UTC, and a send over the limit gets `429` with `Retry-After`.
- **Five active keys per device**, including the device key.
- 100 requests a minute per IP on every endpoint.

### How long can a notification be?

- `title`: 1 to 200 characters, required.
- `message`: up to 16,000 characters.
- `link` and `image`: up to 2,048 characters.

Apple caps a push at 4,000 bytes, so a long notification shows truncated in the banner and in full in the app.

### Why did my send get a 401?

The key is unknown or revoked. Reinstalling the app or moving to a new device makes a new identity, and your old keys stop working.

## Privacy and encryption

### Can you read my notifications?

No. Notifications are encrypted with your device’s public key before the server stores them, and only your device can open them. See the [privacy policy](/privacy).

### What can the server see?

Sender and device IP addresses, your platform and app version, the time of every send and collection, the rough size of each notification, which key sent it and how often, and your push token. See the [privacy policy](/privacy).

### Is it safe to put the key in the URL?

It is the weaker option: a query string ends up in server logs. Use an `Authorization: Bearer` header and a `POST` body instead. See the [docs](/docs).

### How long are notifications kept?

The server deletes a notification as soon as your device has it. An uncollected one waits, encrypted, for up to 90 days. The server keeps revoked keys as hashes so that no one can reuse them.

### What happens if I delete the app?

Your notifications, keys and identity go with it. You can’t recover any of it, and every key stops working.

### Do you track me?

The apps have no analytics, crash reporting or tracking SDK, and this site sets no cookies. The server reports its own errors to Sentry and counts sends and collections, with no content and no IP address. See the [privacy policy](/privacy).

## The apps

### Which devices does it run on?

iPhone and iPad on iOS 17+, Mac on macOS 14+, in the menu bar. There is no Android app: delivery goes through Apple’s push service.

### Where do I get the Mac app?

[Download the DMG](/download/mac), which updates itself, or get it from the [Mac App Store](https://apps.apple.com/app/id1563961135?platform=mac). Both are the same app.

### Can I send to more than one device?

Yes. Create a key on each. A key delivers only to the device that created it.

### How do I revoke a key?

Open the key in the app and tap **Revoke key**. The server refuses the next send that uses it. The app shows a key you create once and never stores it; if you lose it, make a new one.

## Urgent alerts

### What does the urgent toggle do?

A notification sent with `is_critical=1` through a key marked urgent arrives as Time Sensitive: it breaks through Focus and stays on the lock screen.

### Will it ring through silent mode?

No. Time Sensitive breaks through Focus but respects the silent switch.

## Reliability

### Is delivery guaranteed?

No. The server stores every send before it goes out over Apple’s push service and a websocket, so the app can fetch what a push missed. Delivery depends on Apple, your network and your device. See the [terms](/terms).

> **Do not make notifi the only path for anything where a missed notification causes harm.** It is a pager for your own systems, not a life-safety, medical or emergency alerting system.

## Something else

Email [hello@notifi.it](mailto:hello@notifi.it) or open an issue at [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues).
