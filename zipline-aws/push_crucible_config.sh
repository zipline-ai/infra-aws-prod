#!/bin/bash
# Push local config for the crucible deployment back to S3.
#
# Inverse of pull_crucible_config.sh.
set -euo pipefail

aws s3 cp ./terraform.tfvars       s3://zipline-crucible-vars/terraform.tfvars
aws s3 cp ./github.tf              s3://zipline-crucible-vars/github.tf
aws s3 cp ./cloudflare.tf          s3://zipline-crucible-vars/cloudflare.tf
aws s3 cp ./.terraform.lock.hcl    s3://zipline-crucible-vars/.terraform.lock.hcl
aws s3 cp ./crucible-config          s3://zipline-crucible-vars/crucible-config --recursive
