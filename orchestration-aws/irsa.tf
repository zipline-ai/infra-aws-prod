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

  # Read access to the shared warehouse bucket (demo/source data for eval)
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::zipline-warehouse",
      "arn:aws:s3:::zipline-warehouse/*",
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
      "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/*",
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
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "orchestration_cloudwatch_logs" {
  name   = "${var.name_prefix}-orchestration-cloudwatch-logs"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_cloudwatch_logs_policy.json
}

# AMP (Amazon Managed Prometheus) query access for orchestration backend/UI
data "aws_iam_policy_document" "orchestration_amp_policy" {
  statement {
    effect = "Allow"
    actions = [
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [aws_prometheus_workspace.main.arn]
  }
}

resource "aws_iam_role_policy" "orchestration_amp" {
  name   = "${var.name_prefix}-orchestration-amp"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_amp_policy.json
}

# IRSA Role for ADOT Collector
# Allows OpenTelemetry Collector to write metrics to AMP and read pod metrics
data "aws_iam_policy_document" "adot_collector_assume_role" {
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
      values   = ["system:serviceaccount:opentelemetry-operator-system:adot-collector"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "adot_collector" {
  name               = "${var.name_prefix}-adot-collector"
  assume_role_policy = data.aws_iam_policy_document.adot_collector_assume_role.json

  tags = {
    Name = "${var.name_prefix}-adot-collector"
  }
}

# AMP Remote Write permissions for ADOT Collector
data "aws_iam_policy_document" "adot_amp_remote_write" {
  statement {
    effect = "Allow"
    actions = [
      "aps:RemoteWrite",
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
    ]
    resources = [aws_prometheus_workspace.main.arn]
  }
}

resource "aws_iam_role_policy" "adot_amp_remote_write" {
  name   = "${var.name_prefix}-adot-amp-remote-write"
  role   = aws_iam_role.adot_collector.id
  policy = data.aws_iam_policy_document.adot_amp_remote_write.json
}

# ===================================================================
# IRSA Role for Flink Job Execution
# Allows Flink jobs running on EKS to access AWS services via IRSA
# ===================================================================

# Trust policy: Allow the Flink service account to assume this role
data "aws_iam_policy_document" "flink_job_assume_role" {
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
      values   = ["system:serviceaccount:zipline-flink:zipline-flink-sa"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flink_job_execution" {
  name               = "${var.name_prefix}-flink-job-execution"
  assume_role_policy = data.aws_iam_policy_document.flink_job_assume_role.json
  description        = "IAM role for Flink on EKS job execution with IRSA"

  tags = {
    Name = "${var.name_prefix}-flink-job-execution"
  }
}

# S3 access policy for Flink jobs (checkpoints, artifacts, warehouse)
data "aws_iam_policy_document" "flink_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.warehouse_bucket}",
      "arn:aws:s3:::${var.warehouse_bucket}/*",
      "arn:aws:s3:::${trimprefix(var.artifact_prefix, "s3://")}",
      "arn:aws:s3:::${trimprefix(var.artifact_prefix, "s3://")}/*",
      "arn:aws:s3:::zipline-spark-libs",
      "arn:aws:s3:::zipline-spark-libs/*",
    ]
  }
}

resource "aws_iam_policy" "flink_s3" {
  name        = "${var.name_prefix}-flink-s3-policy"
  description = "S3 access policy for Flink jobs"
  policy      = data.aws_iam_policy_document.flink_s3_policy.json
}

resource "aws_iam_role_policy_attachment" "flink_s3" {
  role       = aws_iam_role.flink_job_execution.name
  policy_arn = aws_iam_policy.flink_s3.arn
}

# CloudWatch Logs policy for Flink jobs
data "aws_iam_policy_document" "flink_cloudwatch_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flink_cloudwatch" {
  name   = "${var.name_prefix}-flink-cloudwatch"
  role   = aws_iam_role.flink_job_execution.id
  policy = data.aws_iam_policy_document.flink_cloudwatch_policy.json
}

# Kinesis access policy for Flink jobs
data "aws_iam_policy_document" "flink_kinesis_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kinesis:DescribeStream",
      "kinesis:DescribeStreamSummary",
      "kinesis:GetRecords",
      "kinesis:GetShardIterator",
      "kinesis:ListShards",
      "kinesis:ListStreams",
      "kinesis:SubscribeToShard",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flink_kinesis" {
  name   = "${var.name_prefix}-flink-kinesis"
  role   = aws_iam_role.flink_job_execution.id
  policy = data.aws_iam_policy_document.flink_kinesis_policy.json
}

# DynamoDB access policy for Flink jobs
data "aws_iam_policy_document" "flink_dynamodb_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:CreateTable",
      "dynamodb:DescribeTable",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flink_dynamodb" {
  name   = "${var.name_prefix}-flink-dynamodb"
  role   = aws_iam_role.flink_job_execution.id
  policy = data.aws_iam_policy_document.flink_dynamodb_policy.json
}

# Glue Data Catalog access for orchestration pods (staging queries / exports)
data "aws_iam_policy_document" "orchestration_glue_policy" {
  statement {
    effect = "Allow"
    actions = [
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetPartition",
      "glue:GetPartitions",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "orchestration_glue" {
  name   = "${var.name_prefix}-orchestration-glue"
  role   = aws_iam_role.orchestration_irsa.id
  policy = data.aws_iam_policy_document.orchestration_glue_policy.json
}

# Glue Schema Registry access policy for Flink jobs
data "aws_iam_policy_document" "flink_glue_schema_registry_policy" {
  statement {
    effect = "Allow"
    actions = [
      "glue:GetSchemaVersion",
      "glue:GetSchemaByDefinition",
      "glue:GetRegistry",
      "glue:ListSchemaVersions",
    ]
    resources = [
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:registry/zipline-${var.name_prefix}",
      "arn:aws:glue:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:schema/zipline-${var.name_prefix}/*",
    ]
  }
}

resource "aws_iam_role_policy" "flink_glue_schema_registry" {
  name   = "${var.name_prefix}-flink-glue-schema-registry"
  role   = aws_iam_role.flink_job_execution.id
  policy = data.aws_iam_policy_document.flink_glue_schema_registry_policy.json
}
