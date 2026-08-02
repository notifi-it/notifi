terraform {
  # The R2 S3 endpoint embeds the Cloudflare account id, so it is supplied at init
  # time via -backend-config rather than committed here. See infra/README.md.
  backend "s3" {
    bucket = "notifi-tf-state"
    key    = "infra/terraform.tfstate"
    region = "auto"

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
    use_lockfile                = true
  }
}
