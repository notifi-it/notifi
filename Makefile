.PHONY: dev deploy migration migrate check-migrations migrate-remote typecheck lint gen-vectors gen-copy check-copy \
	app-project app-preflight app-dmg app-testflight app-submit app-appstore \
	app-metadata app-metadata-check app-screenshots app-resubmit shots screens screens-mac

dev:
	cd apps/api && pnpm wrangler dev

deploy:
	cd apps/api && pnpm wrangler deploy

migration:
	cd apps/api && node scripts/new-migration.mjs $(name)

migrate:
	cd apps/api && pnpm wrangler d1 migrations apply notifi-prod --local

migrate-remote:
	cd apps/api && pnpm wrangler d1 migrations apply notifi-prod --remote

typecheck:
	pnpm -r typecheck

check-migrations:
	node scripts/check-migrations.mjs

lint:
	node scripts/lint-comments.mjs

gen-vectors:
	pnpm --filter @notifi/contract gen-vectors

# Copy lives in packages/copy and nowhere else. The API imports it; the app reads
# the Swift file this writes. `check-copy` is the CI half: it regenerates in
# memory and fails if Copy.swift on disk has drifted.
gen-copy:
	pnpm --filter @notifi/copy gen-copy

check-copy:
	pnpm --filter @notifi/copy check-copy

# The landing page's launch animation. Sources are the scene and engine under
# public/gif (the authoring page runs them through a CDN Babel); this bundles
# them with preact for the page itself. Output is committed.
gen-film:
	cd apps/api && node film/build.mjs

app-project:
	cd apps/app && xcodegen generate

# Check tooling, signing identities and credentials without building anything.
app-preflight:
	apps/app/Scripts/with-credentials.sh preflight

# The lanes run xcodegen themselves rather than depending on app-project: it must
# run with DEVELOPMENT_TEAM exported, or project.yml interpolates an empty team and
# every signed build fails with "requires a development team".
#
# macOS ships as a direct-download DMG. It is never uploaded to the App Store.
app-dmg:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane mac dmg

# iOS ships through the App Store, in two steps. `app-testflight` puts a build in
# front of testers; `app-submit` builds the same thing again and submits that
# version for review. SKIP_UPLOAD=1 works on both: it builds and signs without
# uploading or submitting anything.
app-testflight:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios beta

# Submitting for review is not undoable from here -- withdrawing a submission is a
# click in App Store Connect -- so it gets its own target rather than a flag on the
# TestFlight one. Push the listing copy with `app-metadata` first if it changed:
# this lane attaches the binary and submits, it does not upload metadata.
app-submit:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios submit

# `app-appstore` used to mean TestFlight, which stopped being an honest name once
# a real submission target existed. Refuse rather than guess: one of the two
# things it could now mean submits the app for review.
app-appstore:
	@echo "app-appstore is gone -- it meant TestFlight, which was misleading."
	@echo "  make app-testflight   upload a build to TestFlight"
	@echo "  make app-submit       submit the current version for App Store review"
	@exit 1

# App Store listing text lives in apps/app/fastlane/metadata and is pushed from
# there, so the store copy is reviewed like the rest of the repo rather than
# typed into a web form. Screenshots are not managed here -- see the metadata
# lane in the Fastfile for why.
app-metadata-check:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios metadata_check

app-metadata:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios metadata

# Screenshots are their own target because Apple locks them once a version is
# submitted while it leaves the listing text writable -- one target for both
# means a copy fix after submission fails on a half it did not need to touch.
app-screenshots:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios screenshots

# Puts the current version back in review with no new build, for a listing that
# changed after it was submitted. Cancel the open submission first.
app-resubmit:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios resubmit

# Verifying a layout change: one command, one screenshot per tab, from a
# Simulator that stays booted between runs. SKIP_BUILD=1 when no Swift changed.
shots:
	apps/app/Scripts/shots.sh

# Every published iOS screenshot from one command: both App Store sets (the
# iPad one is required — ASC refuses a submission without ipadPro129) and the
# four device shots in apps/api/public/screens the website shows.
screens:
	apps/app/Scripts/screens.sh

# The website's Mac popover shot. Separate because it builds and drives the
# real macOS app on this machine, and quits it — relaunch the installed app
# afterwards so Mac push re-registers.
screens-mac:
	apps/app/Scripts/screens-mac.sh
