variable "name" {
  type = string
}

variable "allowed_ip_list" {
  description = "CIDR ranges allowed to log in. Applied to human users only, never to the CI service users (GitHub-hosted runner IPs are not stable)."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ip_list) > 0
    error_message = "An empty allow-list would lock every attached user out."
  }
}

variable "comment" {
  type    = string
  default = null
}
