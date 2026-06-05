## ECR Pull-Through Cache
# Allows pulling Docker Hub images through ECR (used by EKS).
#
# All resources below are account-wide singletons keyed by the
# `zipline-private` ECR prefix or the `ecr-pullthroughcache/dockerhub`
# secret name. A second deployment in the same AWS account must set
# `create_ecr_pull_through_cache = false` and reuse the existing cache.

resource "aws_secretsmanager_secret" "dockerhub_creds" {
  count       = var.create_ecr_pull_through_cache ? 1 : 0
  name        = "ecr-pullthroughcache/dockerhub"
  description = "Credentials for ECR Pull Through Cache from Docker Hub"
  kms_key_id  = var.encryption_kms_key_arn != "" ? var.encryption_kms_key_arn : null
}

resource "aws_secretsmanager_secret_version" "dockerhub_creds_val" {
  count     = var.create_ecr_pull_through_cache ? 1 : 0
  secret_id = aws_secretsmanager_secret.dockerhub_creds[0].id
  secret_string = jsonencode({
    username    = "ziplineai"
    accessToken = var.dockerhub_token
  })
}

resource "aws_ecr_pull_through_cache_rule" "dockerhub_rule" {
  count                 = var.create_ecr_pull_through_cache ? 1 : 0
  ecr_repository_prefix = "zipline-private"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = aws_secretsmanager_secret.dockerhub_creds[0].arn
}

resource "aws_ecr_repository_creation_template" "template" {
  count       = var.create_ecr_pull_through_cache ? 1 : 0
  prefix      = "zipline-private"
  description = "Template for repositories pulled from Docker Hub"

  # Permission to allow EKS nodes to pull images
  repository_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPull"
      Effect    = "Allow"
      Principal = "*"
      Action    = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
    }]
  })

  applied_for = ["PULL_THROUGH_CACHE"]
}

resource "terraform_data" "prime_ecr_cache" {
  count = var.create_ecr_pull_through_cache ? 1 : 0

  # Re-run this if the version changes or the cache rule changes
  triggers_replace = [
    var.zipline_version,
    aws_ecr_pull_through_cache_rule.dockerhub_rule[0].id
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws ecr batch-get-image \
        --repository-name ${aws_ecr_pull_through_cache_rule.dockerhub_rule[0].ecr_repository_prefix}/ziplineai/hub-aws \
        --image-ids imageTag=${var.zipline_version} \
        --region ${data.aws_region.current.name}
    EOT
  }

  depends_on = [
    aws_ecr_pull_through_cache_rule.dockerhub_rule,
    aws_secretsmanager_secret_version.dockerhub_creds_val
  ]
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
