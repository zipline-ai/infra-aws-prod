output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.base_setup.eks_cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = module.base_setup.eks_cluster_endpoint
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = module.base_setup.kubeconfig_command
}
