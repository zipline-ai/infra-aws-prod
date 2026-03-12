variable "customer_name" {
  description = "Unique identifier for the nightly test deployment (e.g. nightly-42)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.customer_name))
    error_message = "customer_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "dockerhub_token" {
  description = "Docker Hub access token for ECR Pull Through Cache"
  type        = string
  sensitive   = true
}

variable "control_plane_account_id" {
  description = "The AWS account ID of the Zipline control plane"
  type        = string
}
