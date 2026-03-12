variable "customer_name" {
  description = "Unique identifier for the nightly test deployment (e.g. nightly-42)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.customer_name))
    error_message = "customer_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "docker_hub_token" {
  description = "Docker Hub token for pulling Zipline images"
  type        = string
  sensitive   = true
}

variable "zipline_version" {
  description = "Version of Zipline to deploy"
  type        = string
  default     = "0.9.7"
}
