# Privacy policy

> This describes what notifi stores, how long it keeps it, what the server can and cannot read, and what the person sending you a notification can learn about you.

_Last updated 3 August 2026_

## There is no account

notifi has no sign-up, no email address, no password and no device linking. On first launch the app generates two keypairs on the device. The private halves never leave it: the signing key is held in the Secure Enclave and cannot be exported at all, and the decryption key is held in the keychain, marked so that it is not included in iCloud backups or synced to other devices.

The server identifies a device only by its public key. Nothing in the system links that key to a name, an email address or any other identity.

## What the server stores

### Your device

- Two public keys: one for verifying requests, one for encrypting notifications to you.
- Your Apple push token, encrypted with a key held by the server, so notifications can be delivered.
- The platform (`ios` or `macos`) and app version, encrypted with the same key.
- When the device first registered and when it was last seen.

### Your send keys

- A SHA-256 hash of the key. The key itself is never stored, so it cannot be recovered or shown again.
- The name and visible prefix you gave it, encrypted so only your device can read them.
- How many notifications it has sent, when it was created, when it was last used, and whether it is revoked.

### Your notifications

- The notification, encrypted to your device's public key at the moment it arrives.
- Which key sent it, when the server received it, and the event time the sender supplied, if any.

## What the server cannot read

Notification content (the title, body, link and image URL) is encrypted to your device's public key before it is written to the database, using HPKE (P-256 / HKDF-SHA256 / AES-256-GCM). The server holds no private key that can undo this. A full copy of the database, together with every server secret, does not reveal the contents of a single notification. Your send key names are encrypted the same way.

This is what "neither we nor Apple can read your notifications" means on the landing page, and it is the limit of that claim. The sections below cover what remains visible.

## What the server can see

Encrypting the contents does not hide the fact that a notification happened. The server necessarily observes:

- The IP address of whoever sends a notification, and the IP address of your device when it collects one.
- The time of every send and every collection, and the approximate size of each notification.
- Which of your keys sent which notification, and how often each key is used.
- Your Apple push token, which is required to deliver a notification at all.

Because the sender and the recipient both talk to the same server, that server is in a position to correlate the two. If your threat model does not allow for that, notifi is not the right tool.

## How long it is kept

- **Notifications** are deleted from the server as soon as your device confirms it has collected them. A daily job removes them.
- **Uncollected notifications** are kept, encrypted, until your device collects them. There is no time limit.
- **Devices** are kept as long as they are registered. Deleting the app's data on your device is what ends a registration.
- **Send keys** are kept while the device exists, including revoked ones, so that a revoked key cannot be reused.

notifi is a relay, not a mailbox. Once your device has a notification, the server copy is gone and the only copy is the one on your device.

## Server logs

The service runs on Cloudflare Workers. Cloudflare records the metadata of requests reaching the network, including source IP address, timestamp and the full request URL. notifi does not control the contents of those logs and does not write notification contents to logs of its own.

> **This matters for how you send.** The `/send` endpoint accepts a key and a body as URL query parameters, which is convenient for a one-off `curl`. Anything placed in a URL appears in those logs in the clear, before it is ever encrypted, and also in your shell history and in any proxy between you and Cloudflare.
>
> Send the key as an `Authorization: Bearer` header and the body in a `POST` body instead. Neither is logged.

When the server hits an error it cannot handle, a report of that error is sent to Sentry, an error-tracking service, so that it can be fixed. A report carries the failure itself — what broke, and where in the code — along with the request's method and route. It does not carry notification contents, request bodies, headers, or the source IP address. A send key involved in a failed request is replaced, before the report leaves the server, by a short one-way fingerprint of itself: enough to tell that several reports concern the same key, and not enough to recover the key from. Nothing about your device or your notifications is sent to Sentry in the ordinary course of a request; a report exists only where something has gone wrong.

## Images in notifications

A notification can carry a link to an image, and the host serving it is chosen by whoever sent the notification, not by notifi. Loading such an image means your device makes a request to that host, which reveals your IP address, your rough location, and the exact moment the notification reached you. A sender can use this to tell whether and when you received something.

Because of this, the app does not load images automatically. It shows a placeholder and loads the image only when you tap it. If you would rather images appear on their own, there is a switch in **Settings › Privacy**. Turning it on applies to notifications as well, which means images will be fetched on arrival, before you have opened anything.

## On your device

- Collected notifications are stored locally and protected by the device's own encryption. They are readable only after the device has been unlocked at least once since it started.
- Private keys are in the Secure Enclave and the keychain, marked as not backed up and not synced.
- Deleting a notification in the app deletes it from the device. The server copy is already gone.
- Deleting the app deletes the notifications, the keys and the identity. None of it can be recovered afterwards, and any send keys you had created stop working.

## No tracking

The app contains no analytics, no crash reporting and no advertising identifiers — the error reporting described under **Server logs** above is the server's own, and the app takes no part in it. It talks to `notifi.it` and to Apple's push service, and to an image host only when you ask it to load an image. The Mac app additionally embeds Sparkle, an open-source updater, which periodically checks `github.com` for a new release; that request exposes your IP address to GitHub and carries nothing else about you. This website sets no cookies, loads no analytics, and makes no third-party request of any kind: its fonts are served from `notifi.it`.

No data is sold, rented or shared with anyone, and nothing here is used to build a profile or to advertise.

## Children

notifi is not directed at children and collects no information that would identify anyone, of any age.

## Changes and contact

If this policy changes, the date at the top of this page changes with it, and the previous versions remain in the public git history of the project.

Questions about privacy, or a request to delete data held about a device, can be raised at [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues). Note that without your device's public key there is no way to identify which records are yours. Deleting the app is the faster and more complete route.

---

This page as HTML: https://notifi.it/privacy

## More from notifi

- [Home](https://notifi.it/)
- [Docs](https://notifi.it/docs)
- [FAQ](https://notifi.it/faq)
- [Terms](https://notifi.it/terms)
- [llms.txt](https://notifi.it/llms.txt)
- [hello@notifi.it](mailto:hello@notifi.it)
- [GitHub](https://github.com/notifi-it/notifi)
- [X](https://x.com/notifiit)
- [Instagram](https://instagram.com/notifidotit)
- [Facebook](https://facebook.com/notifidotit)
