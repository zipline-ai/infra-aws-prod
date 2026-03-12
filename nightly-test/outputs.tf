output "vpc_id" {
  description = "ID of the VPC"
  value       = module.zipline.vpc_id
}

output "warehouse_bucket" {
  description = "Name of the S3 warehouse bucket"
  value       = module.zipline.warehouse_bucket
}

output "logs_bucket" {
  description = "Name of the S3 logs bucket"
  value       = module.zipline.logs_bucket
}

output "dynamodb_table" {
  description = "Name of the DynamoDB metadata table"
  value       = module.zipline.dynamodb_table
}

output "emr_cluster_id" {
  description = "ID of the EMR cluster"
  value       = module.zipline.emr_cluster_id
}

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.zipline.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.zipline.eks_cluster_endpoint
}

output "rds_endpoint" {
  description = "Endpoint for the RDS PostgreSQL instance"
  value       = module.zipline.rds_endpoint
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.zipline.kubeconfig_command
}

output "hub_url" {
  description = "Hub URL for integration tests (derived from EKS ingress)"
  value       = "http://${module.zipline.eks_cluster_endpoint}:3903"
}
