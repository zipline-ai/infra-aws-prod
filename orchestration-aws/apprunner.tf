## ECR

resource "aws_secretsmanager_secret" "dockerhub_creds" {
  name        = "ecr-pullthroughcache/dockerhub"
  description = "Credentials for ECR Pull Through Cache from Docker Hub"
}

resource "aws_secretsmanager_secret_version" "dockerhub_creds_val" {
  secret_id     = aws_secretsmanager_secret.dockerhub_creds.id
  secret_string = jsonencode({
    username     = "ziplineai"
    accessToken  = var.dockerhub_token
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

  # Permission to allow your App Runner or ECS roles to pull
  repository_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowPull"
      Effect = "Allow"
      Principal = "*"
      Action = ["ecr:BatchGetImage", "ecr:GetDownloadUrlForLayer"]
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

## App Runner Service

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  ecr_base_url = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

resource "aws_apprunner_service" "hub_service" {
  service_name = "zipline-hub-service"

  source_configuration {
    image_repository {
      image_identifier      = "${local.ecr_base_url}/${aws_ecr_pull_through_cache_rule.dockerhub_rule.ecr_repository_prefix}/ziplineai/hub-aws:${var.zipline_version}"
      image_repository_type = "ECR"
      image_configuration {
        port = "3903"
        runtime_environment_variables = {
          "ORCHESTRATION_PORT"           = "3903",
          "AWS_REGION"                   = data.aws_region.current.name,
          "AWS_ACCOUNT_ID"               = data.aws_caller_identity.current.account_id,
          "AWS_DYNAMODB_TABLE_NAME"      = "zipline-metadata",
          "TABLE_PARTITIONS_DATASET"     = "TABLE_PARTITIONS",
          "DATA_QUALITY_METRICS_DATASET" = "DATA_QUALITY_METRICS",
          "CUSTOMER_ID"                  = var.name_prefix,
          "ARTIFACT_PREFIX"              = var.artifact_prefix,
          "DB_URL"                       = aws_db_instance.zipline.address,
          "DB_USERNAME"                  = "locker_user",
          "VERTICLE_CLASS"               = "ai.chronon.hub.AWSOrchestrationVerticle,ai.chronon.hub.AWSWorkflowExecutionVerticle"

        }
        runtime_environment_secrets = {
          "DB_PASSWORD" = aws_db_instance.zipline.master_user_secret[0].secret_arn,
        }
      }
    }

    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_access_role.arn
    }
  }

  health_check_configuration {
    path                = "/ping"
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 1
    unhealthy_threshold = 5
  }

  instance_configuration {
    cpu    = "2048"
    memory = "4096"
    instance_role_arn = aws_iam_role.apprunner_instance_role.arn
  }

  tags = {
    Name = "zipline-hub-service"
  }

  depends_on = [
    terraform_data.prime_ecr_cache,
    aws_iam_role_policy_attachment.apprunner_access_role_policy
  ]
}

resource "aws_iam_role" "apprunner_access_role" {
  name = "zipline-apprunner-access-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "build.apprunner.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_access_role_policy" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
}

resource "aws_iam_role" "apprunner_instance_role" {
  name = "zipline-apprunner-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "tasks.apprunner.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apprunner_instance_role_policy" {
  role       = aws_iam_role.apprunner_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}