# AWS Secrets Manager and IRSA for Secrets Store CSI Driver

# Store database credentials in Secrets Manager
resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "zipline-${var.customer_name}-db-credentials"
  description             = "Database credentials for Zipline orchestration"
  recovery_window_in_days = 7

  tags = {
    Name = "zipline-${var.customer_name}-db-credentials"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = aws_db_instance.orchestration.username
    password = random_password.db_password.result
    host     = "jdbc:postgresql://${aws_db_instance.orchestration.endpoint}/${aws_db_instance.orchestration.db_name}"
    url      = "postgres://${aws_db_instance.orchestration.username}@${aws_db_instance.orchestration.endpoint}/${aws_db_instance.orchestration.db_name}?sslmode=require"
    endpoint = aws_db_instance.orchestration.endpoint
    dbname   = aws_db_instance.orchestration.db_name
  })
}

# IRSA for Secrets Store CSI Driver
data "aws_iam_policy_document" "secrets_csi_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:zipline-system:orchestration-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "secrets_csi" {
  name               = "zipline-${var.customer_name}-secrets-csi-role"
  assume_role_policy = data.aws_iam_policy_document.secrets_csi_assume_role.json

  tags = {
    Name = "zipline-${var.customer_name}-secrets-csi-role"
  }
}

data "aws_iam_policy_document" "secrets_csi_policy" {
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      aws_secretsmanager_secret.db_credentials.arn,
    ]
  }
}

resource "aws_iam_role_policy" "secrets_csi" {
  name   = "zipline-${var.customer_name}-secrets-access"
  role   = aws_iam_role.secrets_csi.id
  policy = data.aws_iam_policy_document.secrets_csi_policy.json
}

# S3 access for orchestration service account
data "aws_iam_policy_document" "orchestration_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.warehouse_bucket}",
      "arn:aws:s3:::${var.warehouse_bucket}/*",
    ]
  }
}

resource "aws_iam_role_policy" "orchestration_s3" {
  name   = "zipline-${var.customer_name}-orchestration-s3"
  role   = aws_iam_role.secrets_csi.id
  policy = data.aws_iam_policy_document.orchestration_s3_policy.json
}
