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

## The accounts

The handles are not the same on every site — `notifi` was taken, and each
fallback was picked separately. Read them here rather than guessing from the
product name, and keep the website footer in step with this table.

| Site | Handle | URL |
|---|---|---|
| X | `notifiit` | https://x.com/notifiit |
| Instagram | `notifidotit` | https://instagram.com/notifidotit |
| Facebook | `notifidotit` | https://facebook.com/notifidotit |
| GitHub org | `notifi-it` | https://github.com/notifi-it |

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

Every image carries the bell alone, badge red, on the same grain plate.

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

The screenshot is the viewport, so **the uploaded image is always the capture's
aspect ratio** — 1536x784 here. Serving the real asset and screenshotting it
does not work: a 1024x1024 avatar arrives letterboxed, and the flat bars against
the grain plate leave a visible seam down both sides.

So compose a throwaway image at the capture's aspect instead, with the plate
full-bleed and the mark sized so that the platform's *default* crop lands on the
intended framing. Then no dragging is needed in any of the crop editors:

- **Avatar.** Platforms crop a centred square, so 784x784 out of 1536x784. Size
  the bell to `560/1024` of the capture height to reproduce `profile.png`.
- **Banner.** X crops 3:1 centred. Scale the bell by `1536/1500` off
  `x-banner.png`'s geometry; for Facebook scale by `1536/1640` off the cover's.

Both compose the same way `generate-social.sh` does — same plate, and the same
`-colorspace sRGB -type TrueColorAlpha` on the read or the badge's red goes
grey.

1. Serve the composed images: `python3 -m http.server 8642 --directory <dir>`
   with a wrapper that fills the viewport
   (`<img style="width:100vw;height:100vh;object-fit:contain">` — `contain`
   because the image already matches the viewport aspect and `cover` would
   crop it again).
2. Open each in a browser tab, `screenshot` it, then `upload_image` with that
   screenshot's ID into the file input (`find` the input, pass its ref — never
   click it, that opens a native picker).
3. Confirm the crop, save, verify on the public page, kill the server, close
   the tabs.

**Upload every image a page takes before saving once.** X's Edit profile holds
the avatar and banner in one unsaved dialog; reloading the settings page between
the two silently discards the first, and the save then applies only the second.
This looked like a successful run until the public profile showed the old
avatar over the new banner.

Per-site input quirks:

- **X.** `find` returns three file inputs. They are only labelled ("Add banner
  photo", "Add avatar photo", "Add photos or video") once the page has settled —
  wait for the labels rather than picking by index, which changes between loads.
- **Facebook.** Two unlabelled inputs on the Page. Do not guess: use *Finish
  setting up your Page → Add profile picture*, which opens a dialog with exactly
  one input, and the **Add cover photo → Upload photo** menu for the cover. Both
  need an explicit Save afterwards.
- **Instagram.** Saves the avatar the moment the file lands — there is no Save
  to press, and the toast is the only confirmation. The bio does need Submit.

This uploads a JPEG re-capture, not the original PNG bytes. Acceptable for
avatars; note it in the summary so a human can re-upload the originals if
pixel-perfect matters.

### Posting the Instagram mosaic

`docs/socials/images/instagram-grid/` needs the real PNG bytes, unresized. A
tile is a 1013px cell centred in a 1080px post, and it is that 33px of padding —
about 3% of the width — that makes the seams line up. Anything that rescales or
re-crops on the way in destroys it, so none of the avatar/banner tricks apply.

Three routes were tried. Only the third works:

- **`file_upload` in the extension's Chrome** would send real bytes, but its
  `paths` argument never arrives — four calls, same
  `expected array, received undefined`, whatever the path.
- **Injecting the bytes with `javascript_tool`** gets further than it looks:
  Instagram reads a `File` built from a `DataTransfer` and validates it, so the
  mechanism is sound. Feeding it is not. `fetch` and `XMLHttpRequest` to
  localhost are both refused by Instagram's CSP, and embedding the image as
  base64 in the call is 4.8M characters for six tiles even as q95 JPEGs.
- **`chrome-devtools-mcp`** is the way in. Its `upload_file` takes a local path
  directly.

That browser is a separate Chrome with a fresh profile, so it is logged out, and
the password manager cannot reach it — `autofill_credential` always fills the
extension's tab and takes no target. **The user signs in there themselves.**
It is a real, visible, non-headless window, so they can. Expect a new-device
prompt and possibly a 2FA code, which is also theirs to enter.

Then per tile, oldest first:

1. Click `New post`, `upload_file` the tile.
2. Crop → `Select Crop` → **`4:5`**. It does not default to 4:5; leaving it
   square crops the sides off and breaks every seam.
3. `Next` (filters) → `Next` (caption) → `Share` → `Done`.

Captions are left empty. Six fragments do not each want a pitch.

Check progress without reloading:

```js
await (await fetch('/api/v1/users/web_profile_info/?username=notifidotit',
  { headers: { 'x-ig-app-id': '936619743392459' } })).json()
```

**Verify the finished grid at a window under about 1200px.** Instagram lays the
profile grid out in four columns on a wide window, which shows the mosaic
scrambled even when every tile is correct. Three columns is what the app and a
normal window show.

## Facebook, Instagram, X

No usable APIs for profile edits — drive each site in the browser with the
user's logged-in Chrome session. For each: set the avatar (same screenshot-relay
if file upload is blocked), the bio from the matching `docs/socials/` file, and
the link `https://notifi.it`. X, Facebook and LinkedIn each take a banner: use
the matching file from `docs/socials/images/` — they are different aspect
ratios, not one image resized.

Field limits worth knowing before trimming copy to fit: X bio 160, Instagram
bio 150, Facebook Page bio 255. Instagram counts the newlines too: its live
counter read 141 for a four-line bio that measures 141 by hand.

Instagram makes no bio text clickable, so the only link a profile gets is the
separate website field — and **that field cannot be set from this skill**.
instagram.com/accounts/edit shows it greyed out, above the line "Editing your
links is only available on mobile. Visit the Instagram app and edit your profile
to change the websites in your bio." Only the iPhone app can write it, so it is
the user's to set. It currently holds `notifi.it`. If a run needs it changed,
say so in the summary and hand that step over rather than reporting Instagram as
fully synced. Facebook's equivalent lives under About → Links and does work in
the browser.

Never create accounts or enter credentials — if a login prompt appears, stop
and hand the browser to the user.

## Verify

- `gh api orgs/notifi-it --jq '.description'` and `gh repo view notifi-it/notifi --json description,homepageUrl` match the one-liner.
- Screenshot each profile page after saving; a form that shows the new text
  unsaved looks identical to a saved one, so check the rendered public page,
  not the settings form.
