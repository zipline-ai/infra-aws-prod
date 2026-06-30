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

data "kubernetes_service_v1" "ui_ingress_controller" {
  count = local.use_zipline_custom_domain || local.ui_domain != "" ? 1 : 0

  metadata {
    name      = "zipline-orchestration-ingress-nginx-ui-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  depends_on = [helm_release.zipline_orchestration]
}

data "kubernetes_service_v1" "hub_ingress_controller" {
  count = !local.use_zipline_custom_domain && local.hub_domain != "" ? 1 : 0

  metadata {
    name      = "zipline-orchestration-ingress-nginx-hub-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  depends_on = [helm_release.zipline_orchestration]
}

data "kubernetes_service_v1" "eval_ingress_controller" {
  count = !local.use_zipline_custom_domain && local.eval_domain != "" ? 1 : 0

  metadata {
    name      = "zipline-orchestration-ingress-nginx-eval-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  depends_on = [helm_release.zipline_orchestration]
}

data "kubernetes_service_v1" "fetcher_ingress_controller" {
  count = !local.use_zipline_custom_domain && local.fetcher_domain != "" && var.deploy_fetcher ? 1 : 0

  metadata {
    name      = "nginx-fetcher-controller"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  depends_on = [helm_release.zipline_orchestration]
}

output "zipline_custom_domain_dns_setup" {
  description = "DNS setup instructions for shared or per-service custom domains. Null when no custom domains are configured."
  value = local.use_zipline_custom_domain || local.ui_domain != "" || local.hub_domain != "" || local.eval_domain != "" || local.fetcher_domain != "" ? {
    mode = local.use_zipline_custom_domain ? "shared_domain" : "per_service_domains"
    certificate_validation_records = local.use_zipline_custom_domain && local.provided_zipline_custom_domain_cert_arn == "" ? [
      for dvo in aws_acm_certificate.zipline_custom_domain_cert[0].domain_validation_options : {
        name   = dvo.resource_record_name
        type   = dvo.resource_record_type
        value  = dvo.resource_record_value
        domain = local.zipline_custom_domain_host
      }
      ] : concat(
      !local.use_zipline_custom_domain && local.ui_domain != "" && var.ui_cert_arn == "" ? [
        for dvo in aws_acm_certificate.ui_cert[0].domain_validation_options : {
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          value  = dvo.resource_record_value
          domain = local.ui_domain
        }
      ] : [],
      !local.use_zipline_custom_domain && local.hub_domain != "" && var.hub_cert_arn == "" ? [
        for dvo in aws_acm_certificate.hub_cert[0].domain_validation_options : {
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          value  = dvo.resource_record_value
          domain = local.hub_domain
        }
      ] : [],
      !local.use_zipline_custom_domain && local.eval_domain != "" && var.eval_cert_arn == "" ? [
        for dvo in aws_acm_certificate.eval_cert[0].domain_validation_options : {
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          value  = dvo.resource_record_value
          domain = local.eval_domain
        }
      ] : [],
      !local.use_zipline_custom_domain && local.fetcher_domain != "" && var.fetcher_cert_arn == "" ? [
        for dvo in aws_acm_certificate.fetcher_cert[0].domain_validation_options : {
          name   = dvo.resource_record_name
          type   = dvo.resource_record_type
          value  = dvo.resource_record_value
          domain = local.fetcher_domain
        }
      ] : [],
    )
    certificate_validation_note = local.use_zipline_custom_domain ? (local.provided_zipline_custom_domain_cert_arn == "" ? "Add these CNAME records to your DNS provider to validate the ACM certificate." : "Using provided zipline_custom_domain_cert_arn; no Terraform-created ACM validation records are required.") : "Add any listed CNAME records to your DNS provider to validate Terraform-created ACM certificates. Services using provided certificate ARNs do not need Terraform-created ACM validation records."
    traffic_records = local.use_zipline_custom_domain ? [
      {
        service         = "zipline"
        type            = "CNAME"
        name            = local.zipline_custom_domain_host
        target_hostname = try(data.kubernetes_service_v1.ui_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "")
        target_command  = "kubectl get svc zipline-orchestration-ingress-nginx-ui-controller -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
        note            = "Point ${local.zipline_custom_domain_host} to the returned UI NLB hostname."
      }
      ] : concat(
      local.ui_domain != "" ? [
        {
          service         = "ui"
          type            = "CNAME"
          name            = local.ui_domain
          target_hostname = try(data.kubernetes_service_v1.ui_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "")
          target_command  = "kubectl get svc zipline-orchestration-ingress-nginx-ui-controller -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
          note            = "Point ${local.ui_domain} to the returned UI NLB hostname."
        }
      ] : [],
      local.hub_domain != "" ? [
        {
          service         = "hub"
          type            = "CNAME"
          name            = local.hub_domain
          target_hostname = try(data.kubernetes_service_v1.hub_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "")
          target_command  = "kubectl get svc zipline-orchestration-ingress-nginx-hub-controller -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
          note            = "Point ${local.hub_domain} to the returned Hub NLB hostname."
        }
      ] : [],
      local.eval_domain != "" ? [
        {
          service         = "eval"
          type            = "CNAME"
          name            = local.eval_domain
          target_hostname = try(data.kubernetes_service_v1.eval_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "")
          target_command  = "kubectl get svc zipline-orchestration-ingress-nginx-eval-controller -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
          note            = "Point ${local.eval_domain} to the returned Eval NLB hostname."
        }
      ] : [],
      local.fetcher_domain != "" ? [
        {
          service         = "fetcher"
          type            = "CNAME"
          name            = local.fetcher_domain
          target_hostname = try(data.kubernetes_service_v1.fetcher_ingress_controller[0].status[0].load_balancer[0].ingress[0].hostname, "")
          target_command  = "kubectl get svc nginx-fetcher-controller -n zipline-system -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
          note            = "Point ${local.fetcher_domain} to the returned Fetcher NLB hostname."
        }
      ] : [],
    )
    service_urls = {
      ui      = local.ui_domain != "" ? "https://${local.ui_domain}${local.ui_path}" : ""
      hub     = local.hub_domain != "" ? "https://${local.hub_domain}${local.hub_path}" : ""
      eval    = local.eval_domain != "" ? "https://${local.eval_domain}${local.eval_path}" : ""
      fetcher = local.fetcher_domain != "" ? "https://${local.fetcher_domain}${local.fetcher_path}" : ""
      polaris = local.ui_domain != "" ? "https://${local.ui_domain}/services/catalog" : ""
    }
  } : null
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

# Flink on EKS outputs — null when in_cluster_compute_enabled=true (K8sSubmitter
# mocks Flink, so Flink-on-EKS infra is skipped).
output "flink_job_role_arn" {
  description = "ARN of the IAM role for Flink job execution with IRSA, or null when Flink-on-EKS is disabled."
  value       = try(aws_iam_role.flink_job_execution[0].arn, null)
}

output "flink_service_account_name" {
  description = "Name of the Kubernetes service account for Flink jobs, or null when Flink-on-EKS is disabled."
  value       = try(kubernetes_service_account_v1.flink_job[0].metadata[0].name, null)
}

output "flink_namespace" {
  description = "Namespace where Flink jobs should be deployed, or null when Flink-on-EKS is disabled."
  value       = try(kubernetes_namespace_v1.zipline_flink[0].metadata[0].name, null)
}

output "databricks_sp_secret_arn" {
  description = "ARN of the Databricks service principal credentials secret (empty if not configured)"
  value       = var.databricks_client_id != "" ? aws_secretsmanager_secret.databricks_sp[0].arn : ""
}

output "databricks_sp_secret_name" {
  description = "Name of the Databricks service principal credentials secret (empty if not configured)"
  value       = var.databricks_client_id != "" ? aws_secretsmanager_secret.databricks_sp[0].name : ""
}
