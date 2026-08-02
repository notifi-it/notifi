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

## Configuration (nothing is hardcoded)

`cloudflare_account_id` and `cloudflare_zone_id` have no defaults, so Terraform fails
loudly if they are unset rather than running against a placeholder. The R2 state
endpoint embeds the account id and is passed at init time:

```bash
export TF_VAR_cloudflare_account_id=<account id>
export TF_VAR_cloudflare_zone_id=<notifi.it zone id>
terraform init -backend-config="endpoints={s3=\"https://$TF_VAR_cloudflare_account_id.r2.cloudflarestorage.com\"}"
```

State locking uses the S3 backend's native lockfile (`use_lockfile`), so a local apply
cannot race CI. This requires Terraform 1.11+.

## Credentials (never committed)

- `CLOUDFLARE_API_TOKEN` — used by the provider for zone/ruleset/R2 management.
- `CLOUDFLARE_READONLY_API_TOKEN` — a read-only token used by the PR `plan` job only.
  `terraform plan` runs provider and data-source code straight from the pull request,
  so that job must never hold a token that can change anything.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` — an R2 S3-API token pair used **only**
  by the state backend. Generate these as an R2 API token in the Cloudflare dashboard.

CI wires these from repository secrets (`CLOUDFLARE_API_TOKEN`,
`CLOUDFLARE_READONLY_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_ZONE_ID`,
`R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`) — see `.github/workflows/infra.yml`.

## Bootstrap ordering

The state bucket is declared in this same config, so the first run is a chicken-and-egg:
create the bucket before the backend can use it. On the very first apply, comment out
`backend.tf`, run `terraform init && terraform apply` against local state to create the
`cloudflare_r2_bucket.tf_state` bucket, then restore `backend.tf` and
`terraform init -migrate-state` to move state into R2. Subsequent runs are ordinary.
