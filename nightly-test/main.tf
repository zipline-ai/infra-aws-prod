# Nightly E2E Test Infrastructure
#
# Mirrors the zipline-aws/ root config but for nightly integration testing.
# Provisioned and destroyed each night by the nightly_e2e GitHub Actions workflow.

module "base_setup" {
  source = "../base-aws"

  customer_name            = var.customer_name
  region                   = "us-west-2"
  artifact_prefix          = "s3://zipline-warehouse-${var.customer_name}"
  dockerhub_token          = var.dockerhub_token
  control_plane_account_id = var.control_plane_account_id
}
