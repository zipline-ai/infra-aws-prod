#!/bin/bash
# Push local config for the crucible-aws (named) deployment back to S3.
# Inverse of pull_crucible_aws_config.sh.
set -euo pipefail

aws s3 cp ./terraform.tfvars       s3://zipline-canary-vars/crucible-aws/terraform.tfvars
aws s3 cp ./github.tf              s3://zipline-canary-vars/crucible-aws/github.tf
aws s3 cp ./cloudflare.tf          s3://zipline-canary-vars/crucible-aws/cloudflare.tf
aws s3 cp ./.terraform.lock.hcl    s3://zipline-canary-vars/crucible-aws/.terraform.lock.hcl
