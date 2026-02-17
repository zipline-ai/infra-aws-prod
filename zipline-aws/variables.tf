variable "region" {
  description = "The AWS region to deploy to."
}

variable "customer_name" {
  description = "Your unique company id"
}

variable "artifact_prefix" {
  description = "The S3 bucket storing Zipline artifacts"
}

variable "dockerhub_token" {
  description = "Docker Hub access token for ECR Pull Through Cache. This should be provided to you by Zipline"
}