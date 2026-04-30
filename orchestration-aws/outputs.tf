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

output "chronon_metadata_table_name" {
  description = "Full name of the Chronon metadata DynamoDB table (with prefix)"
  value       = module.dynamodb_tables.chronon_metadata_table_name
}

output "chronon_metadata_base_name" {
  description = "Base name of the Chronon metadata table (without prefix)"
  value       = module.dynamodb_tables.chronon_metadata_base_name
}

output "table_partitions_table_name" {
  description = "Full name of the table partitions DynamoDB table (with prefix)"
  value       = module.dynamodb_tables.table_partitions_table_name
}

output "table_partitions_base_name" {
  description = "Base name of the table partitions table (without prefix)"
  value       = module.dynamodb_tables.table_partitions_base_name
}

output "dynamodb_table_prefix" {
  description = "The table prefix used for DynamoDB tables"
  value       = module.dynamodb_tables.table_prefix
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

data "kubernetes_service" "ingress_nginx_ui_service" {
  count = var.ui_domain != "" ? 1 : 0
  metadata {
    name      = "zipline-orchestration-ingress-nginx-ui-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }
}

output "ui_nlb_hostname" {
  description = "The hostname of the Network Load Balancer for the UI Ingress Controller"
  value       = var.ui_domain != "" ? data.kubernetes_service.ingress_nginx_ui_service[0].status[0].load_balancer[0].ingress[0].hostname : null
}

output "ui_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.ui_domain"
  value = var.ui_domain != "" ? (<<EOT
To make var.ui_domain work, create a CNAME record with your DNS provider.
Point your desired domain (e.g., ${var.ui_domain}) to the following hostname:
  ${data.kubernetes_service.ingress_nginx_ui_service[0].status[0].load_balancer[0].ingress[0].hostname}
If you are using AWS Route 53, you can create an ALIAS record instead, pointing to the same hostname.
EOT
) : null
}

data "kubernetes_service" "ingress_nginx_hub_service" {
  count = var.hub_domain != "" ? 1 : 0
  metadata {
    name      = "zipline-orchestration-ingress-nginx-hub-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }
}

output "hub_nlb_hostname" {
  description = "The hostname of the Network Load Balancer for the Hub Ingress Controller"
  value       = var.hub_domain != "" ? data.kubernetes_service.ingress_nginx_hub_service[0].status[0].load_balancer[0].ingress[0].hostname : null
}

output "hub_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.hub_domain"
  value = var.hub_domain != "" ? (<<EOT
To make var.hub_domain work, create a CNAME record with your DNS provider.
Point your desired domain (e.g., ${var.hub_domain}) to the following hostname:
  ${data.kubernetes_service.ingress_nginx_hub_service[0].status[0].load_balancer[0].ingress[0].hostname}
If you are using AWS Route 53, you can create an ALIAS record instead, pointing to the same hostname.
EOT
) : null
}

data "kubernetes_service" "ingress_nginx_fetcher_service" {
  count = var.fetcher_domain != "" ? 1 : 0
  metadata {
    name      = "nginx-fetcher-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }
}

output "fetcher_nlb_hostname" {
  description = "The hostname of the Network Load Balancer for the Fetcher Ingress Controller"
  value       = var.fetcher_domain != "" ? data.kubernetes_service.ingress_nginx_fetcher_service[0].status[0].load_balancer[0].ingress[0].hostname : null
}

output "fetcher_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.fetcher_domain"
  value = var.fetcher_domain != "" ? (<<EOT
To make var.fetcher_domain work, create a CNAME record with your DNS provider.
Point your desired domain (e.g., ${var.fetcher_domain}) to the following hostname:
  ${data.kubernetes_service.ingress_nginx_fetcher_service[0].status[0].load_balancer[0].ingress[0].hostname}
If you are using AWS Route 53, you can create an ALIAS record instead, pointing to the same hostname.
EOT
) : null
}

data "kubernetes_service" "ingress_nginx_eval_service" {
  count = var.eval_domain != "" ? 1 : 0
  metadata {
    name      = "zipline-orchestration-ingress-nginx-eval-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }
}

output "eval_nlb_hostname" {
  description = "The hostname of the Network Load Balancer for the Eval Ingress Controller"
  value       = var.eval_domain != "" ? data.kubernetes_service.ingress_nginx_eval_service[0].status[0].load_balancer[0].ingress[0].hostname : null
}

output "eval_cname_setup_instructions" {
  description = "Instructions for setting up the CNAME record for var.eval_domain"
  value = var.eval_domain != "" ? (<<EOT
To make var.eval_domain work, create a CNAME record with your DNS provider.
Point your desired domain (e.g., ${var.eval_domain}) to the following hostname:
  ${data.kubernetes_service.ingress_nginx_eval_service[0].status[0].load_balancer[0].ingress[0].hostname}
If you are using AWS Route 53, you can create an ALIAS record instead, pointing to the same hostname.
EOT
) : null
}
