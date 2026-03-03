variable "region" {
  description = "The AWS region to deploy resources in (e.g., us-west-2, us-east-1)."
}

variable "customer_name" {
  description = "Your unique company identifier. Used as a prefix for naming AWS resources."
}

variable "artifact_prefix" {
  description = "The S3 URI where Zipline artifacts are stored (e.g., s3://your-zipline-artifacts)."
}

variable "dockerhub_token" {
  type        = string
  description = "Docker Hub access token for ECR Pull Through Cache. This should be provided to you by Zipline."
}

variable "control_plane_account_id" {
  description = "The AWS account ID of the Zipline control plane. Provided by Zipline during onboarding."
}

# Custom domains for HTTPS (optional)
variable "ui_domain" {
  description = "Custom domain for the orchestration UI (e.g., zipline.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "hub_domain" {
  description = "Custom domain for the orchestration Hub API (e.g., zipline-hub.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "fetcher_domain" {
  description = "Custom domain for the Chronon fetcher service (e.g., zipline-fetcher.yourcompany.com). Leave empty to use the default load balancer DNS."
  default = ""
}
