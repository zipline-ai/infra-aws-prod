# IRSA (IAM Roles for Service Accounts) for Orchestration Pods
# This allows pods to securely access AWS resources without hardcoded credentials

# Trust policy: Allow the orchestration service account to assume this role
data "aws_iam_policy_document" "orchestration_irsa_assume_role" {
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

resource "aws_iam_role" "orchestration_irsa" {
  name               = "${var.name_prefix}-orchestration-irsa"
  assume_role_policy = data.aws_iam_policy_document.orchestration_irsa_assume_role.json

  tags = {
    Name = "${var.name_prefix}-orchestration-irsa"
  }
}

# Attach the existing RDS secret policy to the IRSA role
# This allows pods to read the database password from Secrets Manager
resource "aws_iam_role_policy_attachment" "orchestration_irsa_rds_secret" {
  role       = aws_iam_role.orchestration_irsa.name
  policy_arn = aws_iam_policy.rds_secret_policy.arn
}

# S3 access policy for orchestration pods
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
  name   = "${var.name_prefix}-orchestration-s3"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_s3_policy.json
}

# DynamoDB access policy for orchestration pods (Chronon metadata)
data "aws_iam_policy_document" "orchestration_dynamodb_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = [
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.dynamodb_table_name}",
    ]
  }
}

resource "aws_iam_role_policy" "orchestration_dynamodb" {
  name   = "${var.name_prefix}-orchestration-dynamodb"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_dynamodb_policy.json
}

# EMR permissions for orchestration pods to submit Spark jobs
data "aws_iam_policy_document" "orchestration_emr_policy" {
  # EMR cluster and job management
  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:RunJobFlow",      # Create transient clusters
      "elasticmapreduce:ListClusters",    # Find existing clusters
      "elasticmapreduce:DescribeCluster", # Get cluster details/status
      "elasticmapreduce:AddJobFlowSteps", # Submit Spark/Flink jobs
      "elasticmapreduce:DescribeStep",    # Track job status
      "elasticmapreduce:CancelSteps",     # Kill running jobs
      "elasticmapreduce:ListSteps",       # List steps on cluster
    ]
    resources = ["*"]
  }

  # EC2 permissions for subnet and security group lookups
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }

  # IAM PassRole - required to pass EMR service and instance profile roles
  # when creating clusters via RunJobFlow
  statement {
    effect = "Allow"
    actions = [
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/zipline_${var.name_prefix}_emr_service_role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/zipline_${var.name_prefix}_emr_profile_role",
    ]
  }
}

resource "aws_iam_role_policy" "orchestration_emr" {
  name   = "${var.name_prefix}-orchestration-emr"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_emr_policy.json
}

# S3 logs bucket access for EMR job logs
data "aws_iam_policy_document" "orchestration_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::zipline-logs-${var.name_prefix}",
      "arn:aws:s3:::zipline-logs-${var.name_prefix}/*",
    ]
  }
}

resource "aws_iam_role_policy" "orchestration_logs" {
  name   = "${var.name_prefix}-orchestration-logs"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_logs_policy.json
}

# CloudWatch Logs access for UI to display container logs
data "aws_iam_policy_document" "orchestration_cloudwatch_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:StartQuery",
      "logs:StopQuery",
      "logs:GetQueryResults",
      "logs:FilterLogEvents",
      "logs:GetLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = [
      "arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${aws_eks_cluster.main.name}/containers:*",
    ]
  }
}

resource "aws_iam_role_policy" "orchestration_cloudwatch_logs" {
  name   = "${var.name_prefix}-orchestration-cloudwatch-logs"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_cloudwatch_logs_policy.json
}
