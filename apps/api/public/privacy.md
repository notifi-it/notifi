# Privacy policy

> What notifi stores, for how long, and what our server can read.

_Last updated 25 September 2026_

## Who runs notifi

Maximilian Mitchell, based in the United Kingdom, runs notifi and is the data controller for everything this policy describes. Contact: [hello@notifi.it](mailto:hello@notifi.it), or [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues) for anything you are happy to discuss in public.

## There is no account

notifi has no sign-up, no email address, no password and no device linking. On first launch the app generates two keypairs on the device. The private halves never leave it: the Secure Enclave holds the signing key and cannot export it, and the keychain holds the decryption key, marked to stay out of iCloud backups and off your other devices.

The server identifies a device only by its public key. Nothing in the system links that key to a name, an email address or any other identity.

## What the server stores

### Your device

- Two public keys: one for verifying requests, one for encrypting notifications to you.
- Your Apple push token, encrypted with a key the server holds, so the server can deliver notifications. Alongside it, a keyed one-way hash of the same token, stored unencrypted: it lets the server recognise that a new registration comes from a device it already knows, so the server can retire the old row instead of sending it duplicates. It identifies the physical device across identity resets, and the server uses it for nothing else.
- The platform (`ios` or `macos`) and the app version, stored in plain text.
- When the device first registered, when the server last saw it, how far it has collected, and a lifetime count of notifications sent to it.
- A daily send counter, used for rate limiting, and the strict-send setting if you have turned it on.

### Your send keys

- A SHA-256 hash of the key. The server never stores the key itself, so it cannot recover the key or show it again.
- The name and visible prefix you gave it, encrypted so only your device can read them.
- How many notifications it has sent, its creation and last-use times, whether it is revoked, and whether it may send urgent notifications.

### Your notifications

- The notification, encrypted to your device’s public key at the moment it arrives.
- Which key sent it, when the server received it, and the event time the sender supplied, if any.

## What the server cannot read

The server encrypts notification content (the title, body, link and image URL) to your device’s public key before writing it to the database, using HPKE (P-256 / HKDF-SHA256 / AES-256-GCM). The server holds no private key that can undo this. Someone holding a full copy of the database and every server secret could not read a single notification. The server encrypts your send key names the same way.

A `/send` request arrives at the server as plaintext, so for the instant between arrival and encryption the content passes through the server’s memory in the clear. The server encrypts it before storing it and leaves it out of notifi’s error reports. If you send with a `POST` body rather than the URL, the logs don’t record it either. The claim "neither we nor Apple can read your notifications" covers stored and delivered notifications.

## What the server can see

Encryption does not hide that a notification happened. The server observes:

- The IP address of whoever sends a notification, and the IP address of your device when it collects one.
- While the app is open, a live connection between your device and the server, which shows the server when the app is running as well as when it collects.
- The time of every send and every collection, and the approximate size of each notification.
- Which of your keys sent which notification, and how often you use each key.
- Your Apple push token, which the server needs to deliver a notification.

Because the sender and the recipient both talk to the same server, that server can correlate the two. If your threat model does not allow for that, notifi is the wrong tool.

## How long the server keeps it

- **Notifications**: the server deletes each one as soon as your device confirms it has collected it.
- **Uncollected notifications**: the server keeps them, encrypted, until your device collects them, for at most 90 days. A daily job deletes anything older.
- **Devices**: the server keeps a device’s row while it is registered. When Apple’s push service reports that the app is gone from a device, the next send to it deletes the registration and everything under it, keys and uncollected notifications included. A device that never receives another send keeps its row until a deletion request removes it; email [hello@notifi.it](mailto:hello@notifi.it) with the device’s public key.
- **Send keys**: the server keeps them while the device exists, revoked ones included, so that no one can reuse a revoked key.
- **Records of sends and collections**: for a send, which device and key it went to, whether the push to Apple succeeded, and the size of the notification in bytes; for a collection, which device and how many notifications it took. Cloudflare’s analytics store keeps them for three months, so notifi can count sends and collections and notice failed deliveries. They hold no content and no IP address.

## Server logs

The service runs on Cloudflare Workers, and two logs record its requests. Cloudflare records the metadata of requests reaching its network, including source IP address, timestamp and the full request URL; those logs are Cloudflare’s own. notifi also enables Cloudflare’s request-log stream for the Worker, which records the same metadata for notifi to read; Cloudflare keeps it for a few days. Neither log contains notification content unless you put it in the URL.

> **Do not put the key in a URL.** The `/send` endpoint accepts a key and a body as URL query parameters, which is convenient for a one-off `curl`. Anything you put in a URL appears in both logs in the clear, before encryption, and in your shell history and any proxy between you and Cloudflare.
>
> Send the key as an `Authorization: Bearer` header and the body in a `POST` body instead. Neither appears in the logs.

When the server hits an error it cannot handle, it sends a report to Sentry, an error-tracking service, so that notifi can fix the error. A report carries the failure itself (what broke, and where in the code) and the request’s method and route. It does not carry notification contents, request bodies, headers, the source IP address, or any identifier of your device or your notifications. Before a report leaves the server, the server replaces any send key involved in the failed request with a short one-way fingerprint of it. The fingerprint shows that several reports concern the same key, and no one can reverse it to recover the key.

## Images in notifications

A notification can carry a link to an image, and whoever sent the notification chooses the host that serves it. To load the image, your device requests it from that host, which reveals your IP address, your rough location, and the exact moment the notification reached you. A sender can use this to tell whether and when you received something.

The app shows a placeholder until you tap it. To load images on arrival, turn on **Load images automatically** in Settings.

## On your device

- The app stores collected notifications on the device, under the device’s own encryption. They are readable only after the first unlock since the device started.
- Private keys are in the Secure Enclave and the keychain, marked as not backed up and not synced.
- Deleting a notification in the app deletes it from the device. The server deleted its copy when your device collected it.
- Deleting the app deletes the notifications, the keys and the identity. You cannot recover any of it afterwards, and any send keys you created stop working.

## Tracking, analytics and third parties

The app contains no analytics, no crash reporting and no advertising identifiers. The error reporting under **Server logs** is the server’s own, and the app takes no part in it. The app talks to `notifi.it` and Apple’s push service, and to an image host only when you ask it to load an image. The Mac app you download from this site also embeds Sparkle, an open-source updater. Once a day Sparkle asks `notifi.it` for the latest release, and `notifi.it` redirects it to `github.com` to fetch it; each check exposes your IP address and its timing to those two hosts and carries nothing else about you.

This website sets no cookies and serves its fonts from `notifi.it`. Cloudflare, which hosts the site, injects its Web Analytics script into the pages: it counts visits without cookies, without a persistent identifier and without following you to other sites, and notifi reads the counts as daily totals. It is the site’s one analytics tool and its one third-party request. Nothing on the site tracks you across sites or over time, so a Do Not Track signal changes nothing: there is no tracking to turn off, and no third party collects data about your activity elsewhere through this site.

Four parties handle data in the ordinary running of the service: Cloudflare (hosting, logs, site analytics), Apple (push delivery), Sentry (error reports, limited as above) and GitHub (serving Mac app updates). notifi sells, rents and shares no data with anyone else, and uses none of it to build a profile or to advertise.

The service also fetches public App Store reviews of notifi from Apple (reviewer name, country, rating and text) and shows them on this site. They are public on the App Store already, and if you ask Apple to remove a review, it disappears here too.

## The legal bases

Under UK and EU law, notifi registers your device, stores your keys, and holds and delivers encrypted notifications as performance of the agreement in the [terms](https://notifi.it/terms): that processing is the service itself. It runs IP-based rate limiting, the request logs and the error reporting under legitimate interests: keeping the service available and preventing abuse. No law requires you to provide any of this data, but delivery needs it, and the service cannot work without it. notifi makes no automated decisions about you and builds no profiles.

## Where the data lives

Cloudflare answers requests at whichever of its data centres is nearest, which may be outside the UK or the EEA; the database is a single Cloudflare D1 instance. Sentry (Functional Software, Inc.) is a US company. Both are certified under the EU-US Data Privacy Framework and its UK extension, and both process data under their standard data-processing agreements ([Cloudflare’s](https://www.cloudflare.com/cloudflare-customer-dpa/), [Sentry’s](https://sentry.io/legal/dpa/)), which include EU standard contractual clauses and the UK addendum as fallback.

## Your rights

UK and EU law gives you rights over data notifi holds about you: access, correction, erasure, restriction, portability and objection. The server cannot tell which records are yours without your device’s public key, so include it in your request; the app can show it. Send requests to [hello@notifi.it](mailto:hello@notifi.it). Deleting the app is faster and more complete for everything except the device row itself. You can also complain to the [Information Commissioner’s Office](https://ico.org.uk) or the supervisory authority where you live.

## Children

notifi is not directed at children. It has no accounts and no profiles; the closest things to identifiers it handles are an IP address and a device’s public key, and it handles them the same way for everyone.

## Changes and contact

This policy may change with the law, Apple’s requirements or the service. The date at the top changes with it, and the git history keeps old versions. notifi announces material changes here first.

Email [hello@notifi.it](mailto:hello@notifi.it) or open an issue at [github.com/notifi-it/notifi/issues](https://github.com/notifi-it/notifi/issues).

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
