terraform {
  required_version = ">= 1.6"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.40"
    }
  }
}

provider "cloudflare" {}

resource "cloudflare_zone_settings_override" "notifi" {
  zone_id = var.cloudflare_zone_id
  settings {
    ssl              = "strict"
    always_use_https = "on"
  }
}

resource "cloudflare_ruleset" "send_rate_limit" {
  zone_id = var.cloudflare_zone_id
  name    = "notifi-send-rate-limit"
  kind    = "zone"
  phase   = "http_ratelimit"

  rules {
    action      = "block"
    description = "300 req/min/IP on /send, block 60s"
    expression  = "(http.request.uri.path eq \"/send\")"
    ratelimit {
      characteristics     = ["ip.src", "cf.colo.id"]
      period              = 60
      requests_per_period = 300
      mitigation_timeout  = 60
    }
  }
}

resource "cloudflare_r2_bucket" "tf_state" {
  account_id = var.cloudflare_account_id
  name       = var.tf_state_bucket
}
