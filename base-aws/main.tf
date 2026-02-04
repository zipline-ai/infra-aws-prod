# Terraform configuration for Zipline base AWS infrastructure

terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# Data sources
data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# IAM policy for personnel (admin access)
data "aws_iam_policy_document" "personnel_policy" {
  count = var.personnel_iam_group != "" ? 1 : 0

  # Full access to Zipline S3 buckets
  statement {
    sid    = "S3FullAccess"
    effect = "Allow"
    actions = [
      "s3:*",
    ]
    resources = [
      aws_s3_bucket.warehouse.arn,
      "${aws_s3_bucket.warehouse.arn}/*",
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }

  # Full access to DynamoDB table
  statement {
    sid    = "DynamoDBFullAccess"
    effect = "Allow"
    actions = [
      "dynamodb:*",
    ]
    resources = [
      aws_dynamodb_table.chronon_metadata.arn,
    ]
  }

  # EMR management access
  statement {
    sid    = "EMRManagement"
    effect = "Allow"
    actions = [
      "elasticmapreduce:*",
    ]
    resources = [
      aws_emr_cluster.main.arn,
    ]
  }

  # Glue management for customer databases
  statement {
    sid    = "GlueManagement"
    effect = "Allow"
    actions = [
      "glue:*",
    ]
    resources = [
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/zipline_${var.customer_name}*",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/zipline_${var.customer_name}*/*",
    ]
  }
}

resource "aws_iam_policy" "personnel_policy" {
  count = var.personnel_iam_group != "" ? 1 : 0

  name        = "zipline-${var.customer_name}-personnel-policy"
  description = "Admin access policy for Zipline personnel"
  policy      = data.aws_iam_policy_document.personnel_policy[0].json
}

resource "aws_iam_group_policy_attachment" "personnel" {
  count = var.personnel_iam_group != "" ? 1 : 0

  group      = var.personnel_iam_group
  policy_arn = aws_iam_policy.personnel_policy[0].arn
}

# IAM policy for users (read access)
data "aws_iam_policy_document" "users_policy" {
  count = var.users_iam_group != "" ? 1 : 0

  # Read access to S3 buckets
  statement {
    sid    = "S3ReadAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
    ]
    resources = [
      aws_s3_bucket.warehouse.arn,
      "${aws_s3_bucket.warehouse.arn}/*",
    ]
  }

  # Read access to DynamoDB table
  statement {
    sid    = "DynamoDBReadAccess"
    effect = "Allow"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable",
    ]
    resources = [
      aws_dynamodb_table.chronon_metadata.arn,
    ]
  }

  # Read access to EMR
  statement {
    sid    = "EMRReadAccess"
    effect = "Allow"
    actions = [
      "elasticmapreduce:Describe*",
      "elasticmapreduce:List*",
    ]
    resources = [
      aws_emr_cluster.main.arn,
    ]
  }

  # Read access to Glue catalog
  statement {
    sid    = "GlueReadAccess"
    effect = "Allow"
    actions = [
      "glue:Get*",
      "glue:BatchGet*",
    ]
    resources = [
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/zipline_${var.customer_name}*",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/zipline_${var.customer_name}*/*",
    ]
  }
}

resource "aws_iam_policy" "users_policy" {
  count = var.users_iam_group != "" ? 1 : 0

  name        = "zipline-${var.customer_name}-users-policy"
  description = "Read access policy for Zipline users"
  policy      = data.aws_iam_policy_document.users_policy[0].json
}

resource "aws_iam_group_policy_attachment" "users" {
  count = var.users_iam_group != "" ? 1 : 0

  group      = var.users_iam_group
  policy_arn = aws_iam_policy.users_policy[0].arn
}
