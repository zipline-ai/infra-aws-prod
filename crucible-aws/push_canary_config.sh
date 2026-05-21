#!/bin/bash
# Push canary tfvars for this module back to S3 after editing locally.
# Inverse of `pull_canary_config.sh`.
set -euo pipefail

aws s3 cp ./crucible.auto.tfvars s3://zipline-canary-vars/crucible.auto.tfvars
