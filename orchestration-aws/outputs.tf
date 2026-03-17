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

# AWS Managed Prometheus outputs
output "amp_workspace_id" {
  description = "ID of the AWS Managed Prometheus workspace"
  value       = aws_prometheus_workspace.main.id
}

output "amp_workspace_arn" {
  description = "ARN of the AWS Managed Prometheus workspace"
  value       = aws_prometheus_workspace.main.arn
}

output "amp_workspace_endpoint" {
  description = "Prometheus endpoint for the workspace (use for remote_write)"
  value       = aws_prometheus_workspace.main.prometheus_endpoint
}

output "amp_query_endpoint" {
  description = "Query endpoint for PromQL queries"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/query"
}

output "amp_remote_write_endpoint" {
  description = "Remote write endpoint for Prometheus scrapers"
  value       = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
}

output "amp_scraper_arn" {
  description = "ARN of the AWS managed Prometheus scraper"
  value       = aws_prometheus_scraper.main.arn
}

# Flink on EKS outputs
output "flink_job_role_arn" {
  description = "ARN of the IAM role for Flink job execution with IRSA"
  value       = aws_iam_role.flink_job_execution.arn
}

output "flink_service_account_name" {
  description = "Name of the Kubernetes service account for Flink jobs"
  value       = kubernetes_service_account_v1.flink_job.metadata[0].name
}

output "flink_namespace" {
  description = "Namespace where Flink jobs should be deployed"
  value       = kubernetes_namespace_v1.zipline_flink.metadata[0].name
}

output "databricks_sp_secret_arn" {
  description = "ARN of the Databricks service principal credentials secret (empty if not configured)"
  value       = var.databricks_client_id != "" ? aws_secretsmanager_secret.databricks_sp[0].arn : ""
}

output "databricks_sp_secret_name" {
  description = "Name of the Databricks service principal credentials secret (empty if not configured)"
  value       = var.databricks_client_id != "" ? aws_secretsmanager_secret.databricks_sp[0].name : ""
}
