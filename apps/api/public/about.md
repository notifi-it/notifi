# About notifi

> notifi turns one HTTP request into a native push notification on your iPhone, iPad or Mac. This page covers who builds it, how it is run, and what it deliberately does not do.

## What notifi is

A push-notification relay for people who write scripts. You install the app, copy the send key it makes on first launch, and any program that can make an HTTP request to `notifi.it` can put a notification on your device — a backup script, a cron job, a CI pipeline, a coding agent, a home server that noticed a disk filling up.

There is no account, no sign-up and no SDK. The app generates a keypair on the device on first launch, and that keypair is the identity; the server knows a device only by its public key. Notification content is encrypted with your public key before it is written down, so neither we nor Apple can read your notifications.

## Who builds it

notifi is built and run by Maximilian Mitchell, an independent developer. It is not a venture-backed company and has no staff: it is one person, one codebase and one endpoint, which is also why the surface stays as small as it is.

The whole product is open source under the [notifi-it/notifi](https://github.com/notifi-it/notifi) repository — the iOS and Mac app, the API that runs on Cloudflare Workers, and the cryptography that seals every notification. Every claim on this site can be checked against that source rather than taken on trust, and every change to the privacy policy stays in the public git history.

## How it is run

- **The service** is a single Cloudflare Worker with a D1 database, talking to Apple's push service. There is one environment, and a merge to `main` is live immediately.
- **The apps** are native: SwiftUI on iOS and macOS. The iPhone and iPad app ships through the App Store; the Mac app is a direct download that updates itself.
- **The cost** is nothing. notifi is free, has no paid tier, and sells no data. Nothing here is funded by advertising, because nothing here is observable enough to advertise against.
- **The limits** are 60 notifications an hour per device and five active send keys per device — enough for a pager, not enough for a mailing list.

## What notifi is not

It is a pager for your own systems. It is not a life-safety, medical or emergency alerting system, not a marketing channel, and not a way to reach anyone who has not given you one of their own send keys — a key delivers only to the device that created it, so there is no way to notify a stranger.

Delivery is not guaranteed. Apple's push service is best-effort and so is notifi, which is why the [terms](https://notifi.it/terms) ask you not to make it the only path for anything where a missed notification causes harm.

## Where to go next

- [API documentation](https://notifi.it/docs) — the endpoint, its parameters and its error codes.
- [llms.txt](https://notifi.it/llms.txt) — the same thing as plain text, written for coding agents.
- [FAQ](https://notifi.it/faq) — cost, limits, encryption, what happens when you delete the app.
- [Privacy policy](https://notifi.it/privacy) and [terms of service](https://notifi.it/terms).
- [Contact](https://notifi.it/contact) — how to reach a human about notifi.

---

This page as HTML: https://notifi.it/about

## More from notifi

- [Home](https://notifi.it/)
- [Docs](https://notifi.it/docs)
- [FAQ](https://notifi.it/faq)
- [Privacy](https://notifi.it/privacy)
- [Terms](https://notifi.it/terms)
- [llms.txt](https://notifi.it/llms.txt)
- [Contact](https://notifi.it/contact)
- [GitHub](https://github.com/notifi-it/notifi)
- [X](https://x.com/notifiit)
- [Instagram](https://instagram.com/notifidotit)
- [Facebook](https://facebook.com/notifidotit)
