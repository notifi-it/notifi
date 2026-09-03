# Privacy policy

> This describes what notifi stores, how long it keeps it, what the server can and cannot read, and what the person sending you a notification can learn about you.

_Last updated 29 August 2026_

## Who runs notifi

notifi is run by Maximilian Mitchell, based in the United Kingdom, who is the data controller for everything this policy describes. Contact: [hello@notifi.it](mailto:hello@notifi.it), or [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues) for anything that can be discussed in public.

## There is no account

notifi has no sign-up, no email address, no password and no device linking. On first launch the app generates two keypairs on the device. The private halves never leave it: the signing key is held in the Secure Enclave and cannot be exported at all, and the decryption key is held in the keychain, marked so that it is not included in iCloud backups or synced to other devices.

The server identifies a device only by its public key. Nothing in the system links that key to a name, an email address or any other identity.

## What the server stores

### Your device

- Two public keys: one for verifying requests, one for encrypting notifications to you.
- Your Apple push token, encrypted with a key held by the server, so notifications can be delivered. Alongside it, a keyed one-way hash of the same token, stored unencrypted: it lets the server recognise that a new registration comes from a device it already knows, so the old row can be retired instead of receiving duplicates. It identifies the physical device across identity resets, and this is the only thing it is used for.
- The platform (`ios` or `macos`) and app version, encrypted with the same key.
- When the device first registered, when it was last seen, how far it has collected, and a lifetime count of notifications sent to it.
- A rolling one-hour send counter, used for rate limiting, and the strict-send setting if you have turned it on.

### Your send keys

- A SHA-256 hash of the key. The key itself is never stored, so it cannot be recovered or shown again.
- The name and visible prefix you gave it, encrypted so only your device can read them.
- How many notifications it has sent, when it was created, when it was last used, whether it is revoked, whether it may send critical notifications, and a rolling one-hour send counter.

### Your notifications

- The notification, encrypted to your device’s public key at the moment it arrives.
- Which key sent it, when the server received it, and the event time the sender supplied, if any.

## What the server cannot read

Notification content (the title, body, link and image URL) is encrypted to your device’s public key before it is written to the database, using HPKE (P-256 / HKDF-SHA256 / AES-256-GCM). The server holds no private key that can undo this. A full copy of the database, together with every server secret, does not reveal the contents of a single notification. Your send key names are encrypted the same way.

One moment sits before that encryption: a `/send` request arrives at the server as plaintext, and for the instant between arrival and encryption the content passes through the server’s memory in the clear. It is encrypted before it is stored, it is not written to notifi’s error reports, and — if you send with a `POST` body rather than the URL — it is not written to logs either. "Neither we nor Apple can read your notifications" is a claim about stored and delivered notifications, and that is its exact scope.

## What the server can see

Encrypting the contents does not hide the fact that a notification happened. The server necessarily observes:

- The IP address of whoever sends a notification, and the IP address of your device when it collects one.
- While the app is open, a live connection between your device and the server, which means the server can see when the app is running, not just when it collects.
- The time of every send and every collection, and the approximate size of each notification.
- Which of your keys sent which notification, and how often each key is used.
- Your Apple push token, which is required to deliver a notification at all.

Because the sender and the recipient both talk to the same server, that server is in a position to correlate the two. If your threat model does not allow for that, notifi is not the right tool.

## How long it is kept

- **Notifications** have their content deleted from the server as soon as your device confirms it has collected them. What stays, for up to a day, is only that a notification was sent to your device and when; the hourly send limit is counted from that.
- **Uncollected notifications** are kept, encrypted, until your device collects them, for at most 90 days. A daily job removes anything older.
- **Devices** are kept as long as they are registered. When Apple’s push service reports that the app has been removed from a device, the next send to it deletes the registration and everything under it — keys and uncollected notifications included. A device that is never sent to again can keep its row until a deletion request removes it; email [hello@notifi.it](mailto:hello@notifi.it) with the device’s public key.
- **Send keys** are kept while the device exists, including revoked ones, so that a revoked key cannot be reused.

notifi is a relay, not a mailbox. Once your device has a notification, the server copy is gone and the only copy is the one on your device.

## Server logs

The service runs on Cloudflare Workers, and its requests are logged twice. Cloudflare records the metadata of requests reaching its network, including source IP address, timestamp and the full request URL; those logs are Cloudflare’s own. notifi additionally enables Cloudflare’s request-log stream for the Worker, which records the same metadata and is readable by notifi; Cloudflare retains it for a matter of days. Neither log contains notification content — unless you put it in the URL, which is the next paragraph.

> **Do not put the key in a URL.** The `/send` endpoint accepts a key and a body as URL query parameters, which is convenient for a one-off `curl`. Anything placed in a URL appears in both logs in the clear, before it is ever encrypted, and also in your shell history and in any proxy between you and Cloudflare.
>
> Send the key as an `Authorization: Bearer` header and the body in a `POST` body instead. Neither is logged.

When the server hits an error it cannot handle, a report of that error is sent to Sentry, an error-tracking service, so that it can be fixed. A report carries the failure itself — what broke, and where in the code — along with the request’s method and route. It does not carry notification contents, request bodies, headers, the source IP address, or any identifier of your device or your notifications. A send key involved in a failed request is replaced, before the report leaves the server, by a short one-way fingerprint of itself. The fingerprint shows that several reports concern the same key and cannot be reversed to recover the key.

## Images in notifications

A notification can carry a link to an image, and the host serving it is chosen by whoever sent the notification, not by notifi. Loading such an image means your device makes a request to that host, which reveals your IP address, your rough location, and the exact moment the notification reached you. A sender can use this to tell whether and when you received something.

Because of this, the app does not load images automatically. It shows a placeholder and loads the image only when you tap it. If you would rather images appear on their own, there is a switch in **Settings › Privacy**. Turning it on applies to notifications as well, which means images will be fetched on arrival, before you have opened anything.

## On your device

- Collected notifications are stored locally and protected by the device’s own encryption. They are readable only after the device has been unlocked at least once since it started.
- Private keys are in the Secure Enclave and the keychain, marked as not backed up and not synced.
- Deleting a notification in the app deletes it from the device. The server copy is already gone.
- Deleting the app deletes the notifications, the keys and the identity. None of it can be recovered afterwards, and any send keys you had created stop working.

## Tracking, analytics and third parties

The app contains no analytics, no crash reporting and no advertising identifiers — the error reporting described under **Server logs** above is the server’s own, and the app takes no part in it. It talks to `notifi.it` and to Apple’s push service, and to an image host only when you ask it to load an image. The Mac app additionally embeds Sparkle, an open-source updater, which periodically asks `notifi.it` for the latest release and is redirected to `github.com` to fetch it; each check exposes your IP address and its timing to those two hosts and carries nothing else about you.

This website sets no cookies and serves its fonts from `notifi.it`. Cloudflare, which hosts the site, injects its Web Analytics script into the pages: it counts visits without cookies, without a persistent identifier and without following you to other sites, and the counts are read by notifi as daily totals. It is the site’s one analytics tool and its one third-party request. Because nothing on the site tracks you across sites or over time, a Do Not Track signal changes nothing: there is no tracking to turn off, and no third party collects data about your activity elsewhere through this site.

The parties that touch data in the ordinary running of the service are Cloudflare (hosting, logs, site analytics), Apple (push delivery), Sentry (error reports, as limited above) and GitHub (serving Mac app updates). No data is sold, rented or shared with anyone else, and nothing here is used to build a profile or to advertise.

One more dataset the service holds: public App Store reviews of notifi — reviewer name, country, rating and text — are fetched from Apple and shown on this site. They are already public on the App Store; asking Apple to remove a review removes it here too.

## The legal bases

For UK and EU law: registering your device, storing your keys, and holding and delivering encrypted notifications are processed because they are the service itself — performance of the agreement described in the [terms](https://notifi.it/terms). IP-based rate limiting, the request logs and the error reporting are processed under legitimate interests: keeping the service available and preventing abuse. Providing any of this data is not a legal requirement; it is simply what delivery needs, and without it the service cannot function. notifi makes no automated decisions about you and builds no profiles.

## Where the data lives

Cloudflare answers requests at whichever of its data centres is nearest, which may be outside the UK or the EEA; the database is a single Cloudflare D1 instance. Sentry (Functional Software, Inc.) is a US company. Both are certified under the EU-US Data Privacy Framework and its UK extension, and both process data under their standard data-processing agreements ([Cloudflare’s](https://www.cloudflare.com/cloudflare-customer-dpa/), [Sentry’s](https://sentry.io/legal/dpa/)), which include EU standard contractual clauses and the UK addendum as fallback.

## Your rights

UK and EU law gives you rights over data held about you: access, correction, erasure, restriction, portability and objection. The server cannot tell which records are yours without your device’s public key — that is the design, not an obstacle — so a request should include it; the app can show it. Requests go to [hello@notifi.it](mailto:hello@notifi.it). Deleting the app is the faster and more complete route for everything except the device row itself. You can also complain to the [Information Commissioner’s Office](https://ico.org.uk) or the supervisory authority where you live.

## Children

notifi is not directed at children. It has no accounts and no profiles; the closest things to identifiers it handles are an IP address and a device’s public key, described above, and they are handled the same way for everyone.

## Changes and contact

This policy may change to reflect changes in the law, in Apple’s requirements, or in what the service does. When it changes, the date at the top changes with it, the previous versions remain in the public git history of the project, and a material change is announced on this site before it takes effect.

Questions about privacy, or a request to delete data held about a device, can be raised at [hello@notifi.it](mailto:hello@notifi.it) or [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues).

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
