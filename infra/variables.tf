variable "cloudflare_account_id" {
  type    = string
  default = "TODO_CLOUDFLARE_ACCOUNT_ID"
}

variable "cloudflare_zone_id" {
  type    = string
  default = "TODO_NOTIFI_IT_ZONE_ID"
}

variable "zone_name" {
  type    = string
  default = "notifi.it"
}

variable "tf_state_bucket" {
  type    = string
  default = "notifi-tf-state"
}
