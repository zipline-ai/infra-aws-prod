# One-time bootstrap: creates the S3 bucket and DynamoDB table used for
# Terraform remote state by the nightly-test wrapper module.
#
# Apply manually once:
#   cd nightly-test/bootstrap
#   terraform init
#   terraform apply

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Project     = "Zipline"
      ManagedBy   = "Terraform"
      Environment = "nightly-test"
    }
  }
}

resource "aws_s3_bucket" "tf_state" {
  bucket = "zipline-nightly-tf-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tf_locks" {
  name         = "zipline-nightly-tf-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "state_bucket" {
  description = "S3 bucket for nightly-test Terraform state"
  value       = aws_s3_bucket.tf_state.bucket
}

output "lock_table" {
  description = "DynamoDB table for nightly-test Terraform state locking"
  value       = aws_dynamodb_table.tf_locks.name
}
