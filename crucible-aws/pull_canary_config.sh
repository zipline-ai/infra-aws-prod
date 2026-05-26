#!/bin/bash
# Pull canary config for this module from S3. Run before `terraform init/
# plan/apply` against the canary account so env-specific values and Zipline-only
# overlays land alongside the generic skeleton.
#
# Lives in the same bucket as zipline-aws and other canary modules
# (`zipline-canary-vars`); the `crucible.` filename prefix keeps it from
# colliding with `terraform.tfvars` belonging to those other modules.
# `.auto.tfvars` is loaded automatically by Terraform, no `-var-file` flag
# needed.
set -euo pipefail

aws s3 cp s3://zipline-canary-vars/crucible.auto.tfvars .
aws s3 cp s3://zipline-canary-vars/crucible.canary.auto.tf .
aws s3 sync s3://zipline-canary-vars/crucible.canary-config ./.canary-config \
  --exclude "*.tfvars" \
  --exclude "*.tfvars.json"
aws s3 cp s3://zipline-canary-vars/crucible.terraform.lock.hcl ./.terraform.lock.hcl
