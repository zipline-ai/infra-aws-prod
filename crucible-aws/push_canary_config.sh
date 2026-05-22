#!/bin/bash
# Push canary config for this module back to S3 after editing locally.
# Inverse of `pull_canary_config.sh`.
set -euo pipefail

aws s3 cp ./crucible.auto.tfvars s3://zipline-canary-vars/crucible.auto.tfvars
aws s3 cp ./crucible.canary.auto.tf s3://zipline-canary-vars/crucible.canary.auto.tf
aws s3 sync ./.canary-config s3://zipline-canary-vars/crucible.canary-config \
  --exclude "*.tfvars" \
  --exclude "*.tfvars.json"
aws s3 cp ./.terraform.lock.hcl s3://zipline-canary-vars/crucible.terraform.lock.hcl
