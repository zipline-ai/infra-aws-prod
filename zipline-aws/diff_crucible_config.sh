#!/bin/bash
# FOR INTERNAL USE ONLY
# Diff local crucible config against the copies stored in S3.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bucket="s3://zipline-crucible-vars"
status=0

aws s3 cp "$bucket/terraform.tfvars" "$tmp_dir/terraform.tfvars"
aws s3 cp "$bucket/github.tf" "$tmp_dir/github.tf"
aws s3 cp "$bucket/cloudflare.tf" "$tmp_dir/cloudflare.tf"
aws s3 cp "$bucket/.terraform.lock.hcl" "$tmp_dir/.terraform.lock.hcl"
aws s3 cp "$bucket/crucible-config" "$tmp_dir/crucible-config" --recursive

diff_file() {
  local file="$1"

  if [[ ! -e "$file" ]]; then
    echo "Local file missing: $file"
    status=1
    return
  fi

  if ! diff -u "$tmp_dir/$file" "$file"; then
    status=1
  fi
}

diff_dir() {
  local dir="$1"

  if [[ ! -d "$dir" ]]; then
    echo "Local directory missing: $dir"
    status=1
    return
  fi

  if ! diff -ruN "$tmp_dir/$dir" "$dir"; then
    status=1
  fi
}

diff_file "terraform.tfvars"
diff_file "github.tf"
diff_file "cloudflare.tf"
diff_file ".terraform.lock.hcl"
diff_dir "crucible-config"

exit "$status"
