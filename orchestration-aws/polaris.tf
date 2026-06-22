locals {
  polaris_realm               = trimspace(var.polaris_realm) != "" ? trimspace(var.polaris_realm) : var.name_prefix
  polaris_storage_external_id = "zipline:${local.polaris_realm}:polaris-storage"
  polaris_storage_allowed_buckets = distinct(compact([
    for bucket in [var.warehouse_bucket] :
    trimsuffix(trimprefix(trimprefix(trimspace(bucket), "s3://"), "s3a://"), "/")
  ]))
  polaris_storage_allowed_locations = [
    for bucket in local.polaris_storage_allowed_buckets : "s3://${bucket}/"
  ]
  polaris_storage_allowed_kms_keys = distinct(compact(concat(
    [var.encryption_kms_key_arn],
    values(var.encryption_kms_key_arns),
  )))
}

resource "random_password" "polaris_root_client_secret" {
  length  = 48
  special = false
}

resource "kubernetes_secret_v1" "polaris_bootstrap_credentials" {
  metadata {
    name      = "polaris-bootstrap-credentials"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  type = "Opaque"

  data = {
    credentials = "${local.polaris_realm},root,${random_password.polaris_root_client_secret.result}"
  }
}

data "aws_iam_policy_document" "polaris_storage_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.orchestration_irsa.arn]
    }
    actions = ["sts:AssumeRole"]
    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [local.polaris_storage_external_id]
    }
  }
}

resource "aws_iam_role" "polaris_storage" {
  name               = "${var.name_prefix}-polaris-storage"
  assume_role_policy = data.aws_iam_policy_document.polaris_storage_assume_role.json
  description        = "Storage credential vending role for the Polaris catalog"

  tags = {
    Name = "${var.name_prefix}-polaris-storage"
  }
}

data "aws_iam_policy_document" "polaris_storage" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
      "s3:ListBucketMultipartUploads",
    ]
    resources = [
      for bucket in local.polaris_storage_allowed_buckets : "arn:aws:s3:::${bucket}"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = [
      for bucket in local.polaris_storage_allowed_buckets : "arn:aws:s3:::${bucket}/*"
    ]
  }

  dynamic "statement" {
    for_each = length(local.polaris_storage_allowed_kms_keys) > 0 ? [1] : []
    content {
      effect = "Allow"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*",
      ]
      resources = local.polaris_storage_allowed_kms_keys
    }
  }
}

resource "aws_iam_role_policy" "polaris_storage" {
  name   = "${var.name_prefix}-polaris-storage"
  role   = aws_iam_role.polaris_storage.id
  policy = data.aws_iam_policy_document.polaris_storage.json
}
