# Outputs for orchestration module

output "eks_cluster_name" {
  description = "Name of the EKS cluster"
  value       = aws_eks_cluster.main.name
}

output "eks_cluster_endpoint" {
  description = "Endpoint for the EKS cluster"
  value       = aws_eks_cluster.main.endpoint
}

output "eks_cluster_arn" {
  description = "ARN of the EKS cluster"
  value       = aws_eks_cluster.main.arn
}

output "eks_cluster_security_group_id" {
  description = "Security group ID of the EKS cluster"
  value       = aws_security_group.eks_cluster.id
}

output "eks_oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.arn
}

output "eks_oidc_provider_url" {
  description = "URL of the OIDC provider for IRSA"
  value       = aws_iam_openid_connect_provider.eks.url
}

output "rds_endpoint" {
  description = "Endpoint for the RDS PostgreSQL instance"
  value       = aws_db_instance.zipline.endpoint
}

output "rds_database_name" {
  description = "Name of the orchestration database"
  value       = aws_db_instance.zipline.db_name
}

output "rds_secret_arn" {
  description = "ARN of the database credentials secret"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "orchestration_irsa_role_arn" {
  description = "ARN of the IRSA role for orchestration service account"
  value       = aws_iam_role.orchestration_irsa.arn
}

output "eks_cluster_ca_certificate" {
  description = "Base64 encoded CA certificate for EKS cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
}

output "kubeconfig_command" {
  description = "Command to update kubeconfig"
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${aws_eks_cluster.main.name}"
}
