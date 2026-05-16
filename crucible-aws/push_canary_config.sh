#!/bin/bash
# Push canary-specific overrides back to S3 after editing locally. Inverse of
# `pull_canary_config.sh`. Run from this directory after you've validated the
# change with `terraform plan` against the canary account.
set -euo pipefail

aws s3 cp ./terraform.tfvars s3://zipline-canary-vars/crucible/
aws s3 cp ./.terraform.lock.hcl s3://zipline-canary-vars/crucible/
