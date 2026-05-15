#!/bin/bash
# Pull canary-specific overrides into this module from S3. Run before
# `terraform init/plan/apply` whenever you're (re)applying against the canary
# account so the env-specific tfvars + extra IAM grants land alongside the
# generic skeleton.
#
# Mirrors zipline-aws/pull_canary_config.sh — same bucket, different prefix.
set -euo pipefail

aws s3 cp s3://zipline-canary-vars/crucible/terraform.tfvars .
aws s3 cp s3://zipline-canary-vars/crucible/canary_chronon_grants.tf .
aws s3 cp s3://zipline-canary-vars/crucible/.terraform.lock.hcl .
