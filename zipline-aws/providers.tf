// Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket = "zipline-ai-opentofu-state-bucket"
    key    = "opentofu-canary-state"
    region = "us-west-1"
  }
}

provider "aws" {
  region  = var.region
  profile = "default"

}

module "base_setup" {
  source = "../base-aws"

  customer_name = var.customer_name
  region        = var.region
  artifact_prefix = var.artifact_prefix
  dockerhub_token = var.dockerhub_token
}
