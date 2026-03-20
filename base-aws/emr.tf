data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "emr_logs" {
  name              = "/emr/zipline-${var.customer_name}"
  retention_in_days = 30
}

###
# IAM Role setups
###

# Shared permissions policy — used by EMR Serverless execution role
data "aws_iam_policy_document" "iam_emr_policy" {
  statement {
    effect = "Allow"
    actions = [
      // EMR
      "elasticmapreduce:Describe*",
      "elasticmapreduce:ListBootstrapActions",
      "elasticmapreduce:ListClusters",
      "elasticmapreduce:ListInstanceGroups",
      "elasticmapreduce:ListInstances",
      "elasticmapreduce:ListSteps",
      // CloudWatch
      "cloudwatch:PutMetricData",
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:PutRetentionPolicy",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
      // DynamoDB
      "dynamodb:DescribeTable",
      "dynamodb:DescribeImport",
      "dynamodb:ImportTable",
      "dynamodb:ListTables",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:CreateTable",
      "dynamodb:DeleteTable",
      "dynamodb:GetRecords",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:UpdateTimeToLive",
      // Glue
      "glue:BatchCreatePartition",
      "glue:BatchDeletePartition",
      "glue:BatchGetPartition",
      "glue:CreateTable",
      "glue:CreateDatabase",
      "glue:CreatePartition",
      "glue:DeleteTable",
      "glue:DeleteDatabase",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:GetTableVersion",
      "glue:GetTableVersions",
      "glue:GetDatabases",
      "glue:GetDatabase",
      "glue:GetSchema",
      "glue:GetSchemaVersion",
      "glue:UpdateTable",
      "glue:UpdateDatabase",
      "glue:UpdatePartition",
      // Kinesis
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:SubscribeToShard",
      // s3
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = ["*"]
  }
}

# Bedrock inference access for EMR Serverless batch jobs (ModelTransformsJob)
data "aws_iam_policy_document" "emr_bedrock_policy" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*",
    ]
  }
}

###
# EMR Serverless
###

# Execution role trusted by EMR Serverless, reuses same permissions as Classic instance profile
data "aws_iam_policy_document" "emr_serverless_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["emr-serverless.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "emr_serverless_role" {
  name               = "zipline_${var.customer_name}_emr_serverless_role"
  assume_role_policy = data.aws_iam_policy_document.emr_serverless_assume_role.json
}

resource "aws_iam_role_policy" "emr_serverless_policy" {
  name   = "zipline_${var.customer_name}_emr_serverless_policy"
  role   = aws_iam_role.emr_serverless_role.id
  policy = data.aws_iam_policy_document.iam_emr_policy.json
}

resource "aws_iam_role_policy" "emr_serverless_bedrock" {
  name   = "zipline_${var.customer_name}_emr_serverless_bedrock_policy"
  role   = aws_iam_role.emr_serverless_role.id
  policy = data.aws_iam_policy_document.emr_bedrock_policy.json
}

resource "aws_emrserverless_application" "spark" {
  name          = "zipline-emr-${var.customer_name}"
  type          = "Spark"
  release_label = "emr-7.12.0"

  auto_start_configuration {
    enabled = true
  }

  auto_stop_configuration {
    enabled              = true
    idle_timeout_minutes = 15
  }

  network_configuration {
    subnet_ids         = [var.emr_subnetwork != "" ? var.emr_subnetwork : aws_subnet.main.id]
    security_group_ids = [aws_security_group.emr_sg.id]
  }
}
