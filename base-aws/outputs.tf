# Outputs from orchestration module needed for provider configuration

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.orchestration.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster API"
  value       = module.orchestration.eks_cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Base64 encoded CA certificate for EKS cluster"
  value       = module.orchestration.eks_cluster_ca_certificate
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = module.orchestration.eks_cluster_arn
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.orchestration.kubeconfig_command
}

output "chronon_metadata_table_name" {
  description = "Name of the Chronon metadata DynamoDB table"
  value       = module.dynamodb_tables.chronon_metadata_table_name
}

output "table_partitions_table_name" {
  description = "Name of the table partitions DynamoDB table"
  value       = module.dynamodb_tables.table_partitions_table_name
}
