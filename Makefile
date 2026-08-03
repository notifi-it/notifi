.PHONY: dev deploy deploy-dev migrate migrate-dev-remote migrate-prod typecheck gen-vectors \
	app-project app-preflight app-dmg app-appstore

dev:
	cd apps/api && pnpm wrangler dev

deploy-dev:
	cd apps/api && pnpm wrangler deploy

deploy:
	cd apps/api && pnpm wrangler deploy --env production

migrate:
	cd apps/api && pnpm wrangler d1 migrations apply notifi-dev --local

migrate-dev-remote:
	cd apps/api && pnpm wrangler d1 migrations apply notifi-dev --remote

migrate-prod:
	cd apps/api && pnpm wrangler d1 migrations apply notifi-prod --remote --env production

typecheck:
	pnpm -r typecheck

gen-vectors:
	pnpm --filter @notifi/contract gen-vectors

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

# iOS ships through the App Store. SKIP_UPLOAD=1 builds and signs without publishing.
app-appstore:
	apps/app/Scripts/with-credentials.sh bundle exec fastlane ios beta
