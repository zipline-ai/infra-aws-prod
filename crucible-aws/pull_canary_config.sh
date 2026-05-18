#!/bin/bash
# Pull canary tfvars for this module from S3. Run before `terraform init/
# plan/apply` against the canary account so the env-specific values land
# alongside the generic skeleton.
#
# Lives in the same bucket as zipline-aws and other canary modules
# (`zipline-canary-vars`); the `crucible.` filename prefix keeps it from
# colliding with `terraform.tfvars` belonging to those other modules.
# `.auto.tfvars` is loaded automatically by Terraform, no `-var-file` flag
# needed.
set -euo pipefail

aws s3 cp s3://zipline-canary-vars/crucible.auto.tfvars .
