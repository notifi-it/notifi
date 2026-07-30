terraform {
  backend "s3" {
    bucket = "notifi-tf-state"
    key    = "infra/terraform.tfstate"
    region = "auto"
    endpoints = {
      s3 = "https://TODO_CLOUDFLARE_ACCOUNT_ID.r2.cloudflarestorage.com"
    }

    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
