terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # Reuse the same state bucket as zipline-aws/ but under a separate key so
  # crucible can plan/apply independently of the canary stack.
  backend "s3" {
    bucket = "zipline-ai-opentofu-state-bucket"
    key    = "opentofu-crucible-state"
    region = "us-west-1"
  }
}

provider "aws" {
  region = var.region
}
