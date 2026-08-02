variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}

variable "zone_name" {
  type    = string
  default = "notifi.it"
}

variable "tf_state_bucket" {
  type    = string
  default = "notifi-tf-state"
}
