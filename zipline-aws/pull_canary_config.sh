#!/bin/bash
# FOR INTERNAL USE ONLY
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -f .terraform.lock.hcl terraform.tfvars github.tf cloudflare.tf
rm -rf .terraform/

# Clear crucible-only config when switching this directory back to canary.
rm -rf crucible-config

aws s3 cp s3://zipline-canary-vars/.terraform.lock.hcl .
aws s3 cp s3://zipline-canary-vars/terraform.tfvars .
aws s3 cp s3://zipline-canary-vars/github.tf .
