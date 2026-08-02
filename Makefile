.PHONY: dev deploy deploy-dev migrate migrate-dev-remote migrate-prod typecheck gen-vectors

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
