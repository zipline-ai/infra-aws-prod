#!/bin/bash
# Pull config for the crucible-aws (named) deployment from S3.
#
# Drives a second zipline-aws deployment named "crucible-aws" (separate
# state, separate Hub at https://crucible-aws.zipline.ai). Lives in the
# zipline-canary-vars bucket under the crucible-aws/ prefix.
#
# Inverse of push_crucible_aws_config.sh.
set -euo pipefail

aws s3 cp s3://zipline-canary-vars/crucible-aws/terraform.tfvars       ./terraform.tfvars
aws s3 cp s3://zipline-canary-vars/crucible-aws/github.tf              ./github.tf
aws s3 cp s3://zipline-canary-vars/crucible-aws/cloudflare.tf          ./cloudflare.tf
aws s3 cp s3://zipline-canary-vars/crucible-aws/.terraform.lock.hcl    ./.terraform.lock.hcl
aws s3 cp s3://zipline-canary-vars/crucible-aws/canary-config          ./canary-config --recursive
