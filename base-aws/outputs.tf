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

output "ui_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.ui_domain"
  value       = module.orchestration.ui_cname_setup_instructions
}

output "hub_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.hub_domain"
  value       = module.orchestration.hub_cname_setup_instructions
}

output "fetcher_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.fetcher_domain"
  value       = module.orchestration.fetcher_cname_setup_instructions
}

output "eval_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.eval_domain"
  value       = module.orchestration.eval_cname_setup_instructions
}
