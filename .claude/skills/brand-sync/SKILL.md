---
name: brand-sync
description: Push notifi's canonical branding (copy, bell mark, og image) out to GitHub, Facebook, Instagram, and X after the copy or artwork changes. Use when marketing copy in docs/socials/ or the marks change, or when asked to sync/update branding anywhere outside the repo.
---

# Brand sync

The repo is the source of truth. External surfaces are copies and drift; this
skill is the procedure for pushing the current truth back out.

## Canonical sources (never write these from a social site backwards)

| Asset | File |
|---|---|
| One-liner (short description everywhere) | `docs/socials/one-liner.txt` |
| Twitter/X bio | `docs/socials/twitter.txt` |
| Instagram bio | `docs/socials/instagram.txt` |
| Facebook short + about | `docs/socials/facebook-short.txt`, `facebook-about.txt` |
| Avatar / profile picture | `docs/socials/images/profile.png` |
| X banner | `docs/socials/images/x-banner.png` |
| Facebook cover | `docs/socials/images/facebook-cover.png` |
| LinkedIn banner | `docs/socials/images/linkedin-banner.png` |
| Site URL | https://notifi.it |

The website itself deploys from `apps/api/public/` on merge to main — it never
needs manual syncing. If the sources above changed, run the sync below.

The images are generated: edit `apps/app/Support/Icon/notifi-logo.svg` and run
`Support/Icon/generate-social.sh`, never the files in `docs/socials/images/`.
`docs/socials/images.txt` says which slot takes which and why.

Two things that are not interchangeable, both of which have been got wrong:

- `apps/api/public/og.png` is **not** a banner. It is 1200x630 and belongs to
  `og:image`; the banners are 3:1 and wider. Using it as a cover letterboxes it.
- `AppIcon.appiconset/icon-1024.png` is **not** the avatar. Same artwork, but on
  the app icon's plate with its corner treatment. `profile.png` is the version
  built for a circular crop.

The lockup's bell badge is white, the standalone avatar's is red — the wordmark
already ends in a red tittle, and two red discs side by side compete.

## GitHub (org `notifi-it`, repo `notifi-it/notifi`)

Text fields go through the API — do not drive the settings form for these; the
Update profile button submit is flaky under automation:

```bash
gh api -X PATCH orgs/notifi-it -f description="$(cat docs/socials/one-liner.txt)" -f name="notifi" -f blog="https://notifi.it"
gh repo edit notifi-it/notifi --description "$(cat docs/socials/one-liner.txt)" --homepage "https://notifi.it"
```

Images have no API and need the Claude-in-Chrome browser:

- Org avatar: https://github.com/organizations/notifi-it/settings/profile
- Repo social preview: https://github.com/notifi-it/notifi/settings (Social preview → Edit)

The extension's `file_upload` tool rejects local paths by design — it only
accepts files the user has shared with the session. The relay below works
around that, so **ask the user before running it**, and do not treat a general
"sync the branding" as covering it. It is here because uploading the project's
own logo is a reasonable thing to want; it is gated because the restriction it
sidesteps is not there by accident.

1. Serve the image locally: `python3 -m http.server 8642 --directory <dir>`
   with an HTML wrapper so it fills the viewport
   (`<img style="width:100vw;height:100vh;object-fit:cover">` for a banner;
   `height:100vh` centred for `profile.png` — GitHub's avatar crop then lands
   exactly on the square).
2. Open it in a browser tab, `screenshot` it, then `upload_image` with that
   screenshot's ID into the settings page's file input (`find` the input,
   pass its ref — never click it, that opens a native picker).
3. Confirm the crop / save, verify the new image renders, kill the server,
   close the tab.

This uploads a JPEG re-capture, not the original PNG bytes. Acceptable for
avatars; note it in the summary so a human can re-upload the originals if
pixel-perfect matters.

## Facebook, Instagram, X

No usable APIs for profile edits — drive each site in the browser with the
user's logged-in Chrome session. For each: set the avatar (same screenshot-relay
if file upload is blocked), the bio from the matching `docs/socials/` file, and
the link `https://notifi.it`. X, Facebook and LinkedIn each take a banner: use the matching file from
`docs/socials/images/` — they are different aspect ratios, not one image resized.

Never create accounts or enter credentials — if a login prompt appears, stop
and hand the browser to the user.

## Verify

- `gh api orgs/notifi-it --jq '.description'` and `gh repo view notifi-it/notifi --json description,homepageUrl` match the one-liner.
- Screenshot each profile page after saving; a form that shows the new text
  unsaved looks identical to a saved one, so check the rendered public page,
  not the settings form.
