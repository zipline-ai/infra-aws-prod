output "cluster_name" {
  description = "EKS cluster name."
  value       = aws_eks_cluster.crucible.name
}

output "cluster_endpoint" {
  description = "EKS API endpoint."
  value       = aws_eks_cluster.crucible.endpoint
}

output "cluster_oidc_issuer" {
  description = "EKS OIDC issuer URL — used as the IRSA trust principal in follow-up PRs."
  value       = aws_eks_cluster.crucible.identity[0].oidc[0].issuer
}

output "cluster_oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider for this cluster."
  value       = aws_iam_openid_connect_provider.oidc.arn
}

output "cluster_region" {
  description = "AWS region (use with `aws eks update-kubeconfig`)."
  value       = var.region
}

output "crucible_bucket_name" {
  description = "S3 bucket name for Crucible event logs / jars / checkpoints."
  value       = aws_s3_bucket.crucible.id
}

output "control_node_group_name" {
  description = "Tainted EKS node group for Hub, ingress, and Crucible control-plane services."
  value       = aws_eks_node_group.control.node_group_name
}

output "data_node_group_name" {
  description = "EKS node group for Chronon engine Spark/Flink data-plane pods."
  value       = aws_eks_node_group.default.node_group_name
}

output "gateway_role_arn" {
  description = "IRSA role ARN for the crucible gateway SA. Plug into `serviceAccount.annotations.eks.amazonaws.com/role-arn` in the helm values."
  value       = aws_iam_role.gateway.arn
}

output "spark_role_arn" {
  description = "IRSA role ARN for the test-ns-a spark + flink SAs. Plug into `sparkDefaults.serviceAccountAnnotations.eks.amazonaws.com/role-arn` in the helm values."
  value       = aws_iam_role.spark.arn
}

###############################################################################
# TLS + ingress
###############################################################################

output "acm_certificate_arn" {
  description = "ACM cert ARN attached to the nginx-ingress NLB."
  value       = aws_acm_certificate.crucible_aws.arn
}

output "acm_validation_records" {
  description = <<-EOT
    DNS validation records to add to your DNS provider so ACM can issue the
    cert. One per cert SAN. After adding them, re-run
    `terraform apply` — the `aws_acm_certificate_validation` resource will
    block until ACM confirms.
  EOT
  value = [
    for dvo in aws_acm_certificate.crucible_aws.domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ]
}

output "ingress_nlb_hostname" {
  description = "NLB hostname provisioned by the nginx-ingress controller. CNAME `<public_host>` to this in your DNS provider."
  value       = try(data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname, "(NLB hostname will appear after first apply completes)")
}

# Reads the nginx-ingress Service after helm release creates it, so the output
# above can surface the NLB hostname terraform-side.
data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = helm_release.ingress_nginx.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}
