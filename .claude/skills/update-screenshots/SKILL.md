---
name: update-screenshots
description: Regenerate every published screenshot — App Store (fastlane) sets and the website's device shots — after a UI change. Trigger with /update-screenshots or when asked to refresh/update the screenshots.
---

# Update all published screenshots

Two make targets cover everything. Run them from the repo root (the directory
you are editing in, so worktrees pick up their own file state).

## 1. iOS: App Store + website

```bash
make screens
```

Builds the app and writes:

- `apps/app/fastlane/screenshots/en-GB/` — both App Store sets (iPhone and the
  mandatory `ipadPro129` 2048x2732 set; ASC refuses a submission without it).
- `apps/api/public/screens/` — the device shots the website shows.

Seeding uses `NOTIFI_SEED_SAMPLE` / `NOTIFI_OPEN_SAMPLE_MESSAGE` (DEBUG only),
no tapping.

## 2. macOS: the website's menu bar popover shot

```bash
make screens-mac
```

Builds and drives the real macOS app on this machine, then quits it. It kills
the user's running copy — **after it finishes, relaunch the installed app** so
Mac push re-registers (a Debug build clobbers the APNs token).

Skip this target unless the Mac popover UI changed; it disturbs the user's
running app.

## Afterwards

- Eyeball every regenerated PNG (Read them) before committing: right content,
  no debug artifacts, seeded data present.
- Commit on a branch and open a PR with the images attached (the PR rule: one
  screenshot per touched screen).
- Pushing the new sets to App Store Connect is a separate, deliberate step
  (`make app-metadata` during a release) — regenerating the files does not
  upload anything.
