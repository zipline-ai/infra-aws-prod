## ECR Pull-Through Cache
# Allows pulling Docker Hub images through ECR (used by EKS)

resource "aws_secretsmanager_secret" "dockerhub_creds" {
  name        = "ecr-pullthroughcache/dockerhub"
  description = "Credentials for ECR Pull Through Cache from Docker Hub"
}

resource "aws_secretsmanager_secret_version" "dockerhub_creds_val" {
  secret_id = aws_secretsmanager_secret.dockerhub_creds.id
  secret_string = jsonencode({
    username    = "ziplineai"
    accessToken = var.dockerhub_token
  })
}

resource "aws_ecr_pull_through_cache_rule" "dockerhub_rule" {
  ecr_repository_prefix = "zipline-private"
  upstream_registry_url = "registry-1.docker.io"
  credential_arn        = aws_secretsmanager_secret.dockerhub_creds.arn
}

resource "aws_ecr_repository_creation_template" "template" {
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
  # Re-run this if the version changes or the cache rule changes
  triggers_replace = [
    var.zipline_version,
    aws_ecr_pull_through_cache_rule.dockerhub_rule.id
  ]

  provisioner "local-exec" {
    command = <<EOT
      aws ecr batch-get-image \
        --repository-name ${aws_ecr_pull_through_cache_rule.dockerhub_rule.ecr_repository_prefix}/ziplineai/hub-aws \
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
