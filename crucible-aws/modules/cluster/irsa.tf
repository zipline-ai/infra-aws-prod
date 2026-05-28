###############################################################################
# IRSA: crucible-gateway
#
# Used by the `crucible` ServiceAccount in `crucible-system`. The gateway pod
# uses this role to: (1) read/write S3 (jar staging, event logs), (2) create
# per-namespace IAM roles on the fly (the CreateIdentity flow in
# pkg/cloud/aws.go), (3) STS GetCallerIdentity at startup.
###############################################################################

data "aws_caller_identity" "current" {}

locals {
  oidc_host = replace(aws_iam_openid_connect_provider.oidc.url, "https://", "")
}

data "aws_iam_policy_document" "gateway_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:crucible-system:crucible"]
    }
  }
}

resource "aws_iam_role" "gateway" {
  name               = "crucible-gateway"
  assume_role_policy = data.aws_iam_policy_document.gateway_assume_role.json

  tags = {
    Name = "crucible-gateway"
  }
}

# S3 access to the crucible bucket (event logs, jar staging, archive db).
data "aws_iam_policy_document" "gateway_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.crucible.arn,
      "${aws_s3_bucket.crucible.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "gateway_s3" {
  name   = "crucible-gateway-s3"
  role   = aws_iam_role.gateway.id
  policy = data.aws_iam_policy_document.gateway_s3.json
}

# IAM: gateway provisions per-namespace IRSA roles for new tenants
# (pkg/cloud/aws.go::CreateIdentity). Scoped to roles named `crucible-*`.
data "aws_iam_policy_document" "gateway_iam" {
  statement {
    effect = "Allow"
    actions = [
      "iam:CreateRole",
      "iam:GetRole",
      "iam:DeleteRole",
      "iam:TagRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/crucible-*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["iam:GetOpenIDConnectProvider"]
    resources = [aws_iam_openid_connect_provider.oidc.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = [aws_eks_cluster.crucible.arn]
  }
}

resource "aws_iam_role_policy" "gateway_iam" {
  name   = "crucible-gateway-iam"
  role   = aws_iam_role.gateway.id
  policy = data.aws_iam_policy_document.gateway_iam.json
}

###############################################################################
# IRSA: crucible-spark
#
# Bootstrap role for the spark-operator-spark + flink SAs in the default
# Crucible job namespace. The gateway will mint additional per-namespace roles
# via CreateIdentity for any other managed namespaces.
###############################################################################

data "aws_iam_policy_document" "spark_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.oidc.arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values = [
        "system:serviceaccount:${var.job_namespace}:spark-operator-spark",
        "system:serviceaccount:${var.job_namespace}:flink",
      ]
    }
  }
}

resource "aws_iam_role" "spark" {
  name               = "crucible-spark"
  assume_role_policy = data.aws_iam_policy_document.spark_assume_role.json

  tags = {
    Name = "crucible-spark"
  }
}

# Spark IRSA: access to the cluster's own artifacts bucket only.
#
# Additional Chronon-on-EKS access is attached by chronon_irsa.tf when the
# caller supplies artifact or warehouse buckets. DynamoDB KV-store grants are
# intentionally left out until that workflow is in scope.
data "aws_iam_policy_document" "spark_s3" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      aws_s3_bucket.crucible.arn,
      "${aws_s3_bucket.crucible.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "spark_s3" {
  name   = "crucible-spark-s3"
  role   = aws_iam_role.spark.id
  policy = data.aws_iam_policy_document.spark_s3.json
}
