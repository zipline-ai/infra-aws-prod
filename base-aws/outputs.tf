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
  description = "Full name of the Chronon metadata DynamoDB table (with prefix)"
  value       = module.orchestration.chronon_metadata_table_name
}

output "chronon_metadata_base_name" {
  description = "Base name of the Chronon metadata table (without prefix)"
  value       = module.orchestration.chronon_metadata_base_name
}

output "table_partitions_table_name" {
  description = "Full name of the table partitions DynamoDB table (with prefix)"
  value       = module.orchestration.table_partitions_table_name
}

output "table_partitions_base_name" {
  description = "Base name of the table partitions table (without prefix)"
  value       = module.orchestration.table_partitions_base_name
}
