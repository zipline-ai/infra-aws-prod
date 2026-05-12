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

output "gateway_role_arn" {
  description = "IRSA role ARN for the crucible gateway SA. Plug into `serviceAccount.annotations.eks.amazonaws.com/role-arn` in the helm values."
  value       = aws_iam_role.gateway.arn
}

output "spark_role_arn" {
  description = "IRSA role ARN for the test-ns-a spark + flink SAs. Plug into `sparkDefaults.serviceAccountAnnotations.eks.amazonaws.com/role-arn` in the helm values."
  value       = aws_iam_role.spark.arn
}
