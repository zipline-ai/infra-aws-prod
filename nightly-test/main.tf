# Nightly E2E Test Infrastructure
#
# Thin wrapper around the zipline-aws root module with cost-optimized defaults.
# Provisioned and destroyed each night by the nightly_e2e GitHub Actions workflow.

module "zipline" {
  source = "../zipline-aws"

  customer_name    = var.customer_name
  docker_hub_token = var.docker_hub_token
  zipline_version  = var.zipline_version
  region           = "us-west-2"

  # Cost-optimized EMR: 1x m5.xlarge master, 1x m5.large core, max 3
  emr_master_instance_type = "m5.xlarge"
  emr_core_instance_type   = "m5.large"
  emr_autoscaling_min      = 1
  emr_autoscaling_max      = 3

  # Minimal DynamoDB
  dynamo_read_capacity  = 5
  dynamo_write_capacity = 5

  # Single-node EKS
  eks_instance_type = "m5.xlarge"
  eks_desired_size  = 1
  eks_min_size      = 1
  eks_max_size      = 2

  # Minimal RDS
  rds_instance_class = "db.t3.micro"
  rds_multi_az       = false
}
