#!/bin/bash
# FOR INTERNAL USE ONLY
# Pull config for the crucible deployment from S3.
#
# Drives the parallel "crucible" zipline-aws deployment (separate state from
# crucible-aws). Lives in the zipline-crucible-vars bucket.
#
# Inverse of push_crucible_config.sh.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

rm -f .terraform.lock.hcl terraform.tfvars github.tf cloudflare.tf
rm -rf .terraform/
rm -rf crucible-config

aws s3 cp s3://zipline-crucible-vars/terraform.tfvars       ./terraform.tfvars
aws s3 cp s3://zipline-crucible-vars/github.tf              ./github.tf
aws s3 cp s3://zipline-crucible-vars/cloudflare.tf          ./cloudflare.tf
aws s3 cp s3://zipline-crucible-vars/.terraform.lock.hcl    ./.terraform.lock.hcl
aws s3 cp s3://zipline-crucible-vars/crucible-config          ./crucible-config --recursive
