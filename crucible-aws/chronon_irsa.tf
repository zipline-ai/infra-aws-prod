###############################################################################
# Optional inline policy on the spark IAM role granting the access pattern
# chronon backfill jobs need: read on artifact + warehouse-read buckets,
# read+write on warehouse-write buckets, Glue catalog, DynamoDB tables that
# BatchNodeRunner writes to.
#
# The shape of each statement is universal — every chronon-on-EKS deployment
# needs roughly the same grants. The values (which buckets, which DynamoDB
# account) vary per environment and come from `terraform.tfvars` pulled out of
# `s3://zipline-canary-vars/crucible/` by `pull_canary_config.sh`.
#
# Set `spark_chronon_grants_enabled = false` (the skeleton default) for
# clusters that don't run chronon, and the policy isn't created.
###############################################################################

locals {
  chronon_dynamodb_account = var.chronon_dynamodb_account != "" ? var.chronon_dynamodb_account : data.aws_caller_identity.current.account_id
  chronon_read_buckets     = concat(var.chronon_artifact_buckets, var.chronon_warehouse_read_buckets)
}

data "aws_iam_policy_document" "spark_chronon" {
  count = var.spark_chronon_grants_enabled ? 1 : 0

  # S3 read on artifact (jar download) + warehouse-read buckets. The python
  # integration suite resolves ARTIFACT_PREFIX from
  # chronon/python/test/canary/teams.py so the artifact bucket list must
  # cover whatever each environment publishes its cloud_aws jar into.
  dynamic "statement" {
    for_each = length(local.chronon_read_buckets) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "s3:GetObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      resources = flatten([
        for b in local.chronon_read_buckets : [
          "arn:aws:s3:::${b}",
          "arn:aws:s3:::${b}/*",
        ]
      ])
    }
  }

  # S3 write on warehouse-write buckets. chronon backfill jobs land Iceberg
  # tables here; the warehouse-write set may include the warehouse-read
  # buckets when a single bucket is used for both, but it doesn't have to.
  dynamic "statement" {
    for_each = length(var.chronon_warehouse_write_buckets) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = [for b in var.chronon_warehouse_write_buckets : "arn:aws:s3:::${b}/*"]
    }
  }

  # Glue catalog. The chronon Spark conf wires the AWS Glue Hive client, so
  # every backfill driver issues GetTable/GetPartitions/GetDatabase before
  # writing Iceberg tables. Action set is universal; no value to scope.
  statement {
    effect = "Allow"
    actions = [
      "glue:GetDatabase",
      "glue:GetDatabases",
      "glue:GetTable",
      "glue:GetTables",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:BatchGetPartition",
      "glue:CreateTable",
      "glue:UpdateTable",
      "glue:CreatePartition",
      "glue:BatchCreatePartition",
      "glue:UpdatePartition",
      "glue:BatchUpdatePartition",
      "glue:DeleteTable",
      "glue:DeletePartition",
      "glue:BatchDeletePartition",
    ]
    resources = ["*"]
  }

  # dynamodb:ListTables doesn't accept resource-level ARNs per AWS auth
  # rules — has to live in its own statement with resources = ["*"].
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:ListTables"]
    resources = ["*"]
  }

  # DynamoDB CRUD for chronon's BatchNodeRunner post-job action (writes
  # partition watermarks into `_BATCH` plus per-groupBy upload registries).
  # Scoped to the region + account that holds those tables.
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:CreateTable",
      "dynamodb:UpdateTable",
      "dynamodb:DeleteTable",
      "dynamodb:DescribeContinuousBackups",
      "dynamodb:UpdateContinuousBackups",
      "dynamodb:DescribeImport",
      "dynamodb:ImportTable",
      "dynamodb:DescribeTimeToLive",
      "dynamodb:UpdateTimeToLive",
      "dynamodb:TagResource",
      "dynamodb:UntagResource",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${local.chronon_dynamodb_account}:table/*",
      "arn:aws:dynamodb:${var.region}:${local.chronon_dynamodb_account}:table/*/index/*",
    ]
  }
}

resource "aws_iam_role_policy" "spark_chronon" {
  count  = var.spark_chronon_grants_enabled ? 1 : 0
  name   = "crucible-spark-chronon"
  role   = aws_iam_role.spark.id
  policy = data.aws_iam_policy_document.spark_chronon[0].json
}
