###############################################################################
# Optional inline policy on the spark IAM role granting the access pattern
# chronon backfill jobs need: read on artifact buckets, read+write on warehouse
# buckets, and Glue catalog access.
#
# The shape of each statement is universal — every chronon-on-EKS deployment
# needs roughly the same grants. The values (which buckets) vary per
# environment and come from `terraform.tfvars` pulled out of
# `s3://zipline-canary-vars/crucible/` by `pull_canary_config.sh`.
#
# Every statement is scoped to this account + region — no blanket `*`
# resources. The KV-store (DynamoDB) grants are intentionally omitted: the
# trial is backfills-only. Add them back behind their own toggle if/when
# kvstore upload is in scope.
#
# Auto-skipped when neither bucket list is populated — clusters not running
# chronon get nothing extra on the spark role.
###############################################################################

locals {
  chronon_enabled = length(var.chronon_artifact_buckets) + length(var.chronon_warehouse_buckets) > 0
}

data "aws_iam_policy_document" "spark_chronon" {
  count = local.chronon_enabled ? 1 : 0

  # S3 read on artifact + warehouse buckets. (Warehouse buckets get read here
  # plus write in the next statement — combined effect is read+write.)
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = flatten([
      for b in distinct(concat(var.chronon_artifact_buckets, var.chronon_warehouse_buckets)) : [
        "arn:aws:s3:::${b}",
        "arn:aws:s3:::${b}/*",
      ]
    ])
  }

  # S3 write on warehouse buckets only. chronon backfill jobs land Iceberg
  # tables here.
  dynamic "statement" {
    for_each = length(var.chronon_warehouse_buckets) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "s3:PutObject",
        "s3:DeleteObject",
      ]
      resources = [for b in var.chronon_warehouse_buckets : "arn:aws:s3:::${b}/*"]
    }
  }

  # Glue catalog. The chronon Spark conf wires the AWS Glue Hive client, so
  # every backfill driver issues GetTable/GetPartitions/GetDatabase before
  # writing Iceberg tables. Scoped to the Glue catalog/databases/tables in
  # this account + region — `GetDatabases` needs the `catalog` resource,
  # `GetTables` needs `database/*`, table/partition ops need `table/*/*`.
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
    resources = [
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:catalog",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:database/*",
      "arn:aws:glue:${var.region}:${data.aws_caller_identity.current.account_id}:table/*/*",
    ]
  }
}

resource "aws_iam_role_policy" "spark_chronon" {
  count  = local.chronon_enabled ? 1 : 0
  name   = "crucible-spark-chronon"
  role   = aws_iam_role.spark.id
  policy = data.aws_iam_policy_document.spark_chronon[0].json
}
