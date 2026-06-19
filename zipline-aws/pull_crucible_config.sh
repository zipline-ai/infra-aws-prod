#!/bin/bash
# Pull config for the crucible deployment from S3.
#
# Drives the parallel "crucible" zipline-aws deployment (separate state from
# crucible-aws). Lives in the zipline-crucible-vars bucket.
#
# Inverse of push_crucible_config.sh.
set -euo pipefail

aws s3 cp s3://zipline-crucible-vars/terraform.tfvars       ./terraform.tfvars
aws s3 cp s3://zipline-crucible-vars/github.tf              ./github.tf
aws s3 cp s3://zipline-crucible-vars/cloudflare.tf          ./cloudflare.tf
aws s3 cp s3://zipline-crucible-vars/.terraform.lock.hcl    ./.terraform.lock.hcl
aws s3 cp s3://zipline-crucible-vars/crucible-config          ./crucible-config --recursive
