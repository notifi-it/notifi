# infra — Terraform

Terraform manages only what wrangler cannot express (PLAN.md §11):

- **Zone settings for `notifi.it`** — SSL `strict` (full strict) and `always_use_https`.
- **One edge rate-limit rule** — 300 requests/min/IP on `/send`, block 60s. The free
  plan includes exactly one rate-limit rule; it is spent here as the outermost of the
  three rate-limit layers (§7). The Worker's own per-IP binding and the authoritative
  per-key D1 window are configured in `apps/api`, not here.
- **The R2 bucket** that backs Terraform's own remote state.

The Worker's custom domain (`notifi.it`) is created by wrangler via
`custom_domain = true` in `wrangler.toml` — it is deliberately **not** duplicated here.

## Rate-limit rule leaks the URI — prefer `Authorization: Bearer`

Cloudflare's security-event log records the **full matched URI** for every request the
rule blocks. A blocked `GET /send?key=nk_…` therefore deposits a live send key into the
dashboard and any Logpush destination. This is the reason the API documents
`Authorization: Bearer nk_…` as the default way to pass a key (§7); the query-string
form is for one-off `curl` only. Accepted with eyes open — there is no way to redact
the URI on the free plan.

## Placeholders to fill

- `var.cloudflare_account_id` — `TODO_CLOUDFLARE_ACCOUNT_ID` in `variables.tf`.
- `var.cloudflare_zone_id` — `TODO_NOTIFI_IT_ZONE_ID` in `variables.tf`.
- The R2 S3 endpoint host in `backend.tf` — `TODO_CLOUDFLARE_ACCOUNT_ID`.

## Credentials (never committed)

- `CLOUDFLARE_API_TOKEN` — used by the provider for zone/ruleset/R2 management.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — an R2 S3-API token pair used **only**
  by the state backend. Generate these as an R2 API token in the Cloudflare dashboard.

CI wires all three from repository secrets (`CLOUDFLARE_API_TOKEN`,
`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) — see `.github/workflows/infra.yml`.

## Bootstrap ordering

The state bucket is declared in this same config, so the first run is a chicken-and-egg:
create the bucket before the backend can use it. On the very first apply, comment out
`backend.tf`, run `terraform init && terraform apply` against local state to create the
`cloudflare_r2_bucket.tf_state` bucket, then restore `backend.tf` and
`terraform init -migrate-state` to move state into R2. Subsequent runs are ordinary.
