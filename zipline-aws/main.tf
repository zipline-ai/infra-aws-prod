# Zipline AWS Production Deployment
# This module deploys the complete Zipline infrastructure on AWS

# Base infrastructure module (VPC, S3, DynamoDB, EMR)
module "base" {
  source = "../base-aws"

  region        = var.region
  customer_name = var.customer_name

  # Network configuration
  vpc_cidr = var.vpc_cidr

  # EMR configuration
  emr_master_instance_type = var.emr_master_instance_type
  emr_core_instance_type   = var.emr_core_instance_type
  emr_autoscaling_min      = var.emr_autoscaling_min
  emr_autoscaling_max      = var.emr_autoscaling_max

  # DynamoDB configuration
  dynamo_read_capacity  = var.dynamo_read_capacity
  dynamo_write_capacity = var.dynamo_write_capacity

  # IAM configuration
  personnel_iam_group = var.personnel_iam_group
  users_iam_group     = var.users_iam_group
}

# Orchestration module (EKS, RDS, Helm)
module "orchestration" {
  source = "../orchestration-aws"

  region           = var.region
  customer_name    = var.customer_name
  vpc_id           = module.base.vpc_id
  subnet_ids       = module.base.subnet_ids
  warehouse_bucket = module.base.warehouse_bucket_name
  zipline_version  = var.zipline_version
  docker_hub_token = var.docker_hub_token

  # EKS configuration
  eks_instance_type = var.eks_instance_type
  eks_desired_size  = var.eks_desired_size
  eks_min_size      = var.eks_min_size
  eks_max_size      = var.eks_max_size

  # RDS configuration
  rds_instance_class = var.rds_instance_class
  rds_multi_az       = var.rds_multi_az

  # Domain configuration
  hub_domain = var.hub_domain
  ui_domain  = var.ui_domain
}

# Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.base.vpc_id
}

output "warehouse_bucket" {
  description = "Name of the S3 warehouse bucket"
  value       = module.base.warehouse_bucket_name
}

output "logs_bucket" {
  description = "Name of the S3 logs bucket"
  value       = module.base.logs_bucket_name
}

output "dynamodb_table" {
  description = "Name of the DynamoDB metadata table"
  value       = module.base.dynamodb_table_name
}

output "emr_cluster_id" {
  description = "ID of the EMR cluster"
  value       = module.base.emr_cluster_id
}

output "emr_master_dns" {
  description = "Public DNS of the EMR master node"
  value       = module.base.emr_master_public_dns
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.orchestration.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.orchestration.eks_cluster_endpoint
}

output "rds_endpoint" {
  description = "Endpoint for the RDS PostgreSQL instance"
  value       = module.orchestration.rds_endpoint
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.orchestration.kubeconfig_command
}
