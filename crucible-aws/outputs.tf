output "cluster_name" {
  description = "EKS cluster name."
  value       = module.cluster.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = module.cluster.cluster_endpoint
}

output "cluster_ca_certificate" {
  description = "Base64 encoded CA certificate for the EKS cluster."
  value       = module.cluster.cluster_ca_certificate
}

output "cluster_oidc_issuer" {
  description = "EKS OIDC issuer URL."
  value       = module.cluster.cluster_oidc_issuer
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for this cluster."
  value       = module.cluster.cluster_oidc_provider_arn
}

output "cluster_region" {
  description = "AWS region."
  value       = module.cluster.cluster_region
}

output "crucible_bucket_name" {
  description = "S3 bucket name for Crucible event logs, jars, and checkpoints."
  value       = module.cluster.crucible_bucket_name
}

output "control_node_group_name" {
  description = "Tainted EKS node group for Hub, ingress, and Crucible control-plane services."
  value       = module.cluster.control_node_group_name
}

output "data_node_group_name" {
  description = "EKS node group for Chronon engine Spark/Flink data-plane pods."
  value       = module.cluster.data_node_group_name
}

output "gateway_role_arn" {
  description = "IRSA role ARN for the Crucible gateway service account."
  value       = module.cluster.gateway_role_arn
}

output "spark_role_arn" {
  description = "IRSA role ARN for Spark and Flink service accounts."
  value       = module.cluster.spark_role_arn
}

output "acm_certificate_arn" {
  description = "ACM cert ARN attached to the nginx-ingress NLB."
  value       = module.cluster.acm_certificate_arn
}

output "acm_validation_records" {
  description = "DNS validation records to add to your DNS provider so ACM can issue the cert."
  value       = module.cluster.acm_validation_records
}

output "ingress_nlb_hostname" {
  description = "NLB hostname provisioned by the nginx-ingress controller."
  value       = module.ingress_nginx.ingress_nlb_hostname
}
