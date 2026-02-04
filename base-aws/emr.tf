# EMR cluster for batch compute

resource "aws_emr_cluster" "main" {
  name          = "zipline-${var.customer_name}-emr"
  release_label = var.emr_release_label
  applications  = ["Spark", "Flink", "Hadoop", "Hive", "JupyterEnterpriseGateway", "Livy", "Zeppelin"]

  configurations = jsonencode([
    {
      classification = "spark-hive-site"
      properties = {
        "hive.metastore.client.factory.class" = "com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"
      }
    }
  ])

  ec2_attributes {
    subnet_id                         = var.emr_subnetwork != "" ? var.emr_subnetwork : aws_subnet.main.id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
    emr_managed_master_security_group = aws_security_group.emr_sg.id
    emr_managed_slave_security_group  = aws_security_group.emr_sg.id
  }

  dynamic "bootstrap_action" {
    for_each = var.emr_bootstrap_actions
    content {
      name = bootstrap_action.key
      path = bootstrap_action.value
    }
  }

  master_instance_group {
    instance_type = var.emr_master_instance_type
    ebs_config {
      size                 = var.emr_master_ebs_size
      type                 = "gp3"
      volumes_per_instance = 2
    }
  }

  core_instance_group {
    instance_type = var.emr_core_instance_type
    ebs_config {
      size                 = var.emr_core_ebs_size
      type                 = "gp3"
      volumes_per_instance = 2
    }
  }

  service_role     = aws_iam_role.emr_service_role.arn
  autoscaling_role = aws_iam_role.emr_autoscaling_role.arn
  log_uri          = "s3://${aws_s3_bucket.logs.bucket}/emr/"

  tags = merge(var.emr_tags, {
    Name = "zipline-${var.customer_name}-emr"
  })
}

resource "aws_emr_managed_scaling_policy" "main" {
  cluster_id = aws_emr_cluster.main.id

  compute_limits {
    unit_type                       = "Instances"
    minimum_capacity_units          = var.emr_autoscaling_min
    maximum_capacity_units          = var.emr_autoscaling_max
    maximum_ondemand_capacity_units = var.emr_autoscaling_max
  }
}

# IAM Role for EMR Service
data "aws_iam_policy_document" "emr_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["elasticmapreduce.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "emr_service_role" {
  name               = "zipline-${var.customer_name}-emr-service-role"
  assume_role_policy = data.aws_iam_policy_document.emr_assume_role.json

  tags = {
    Name = "zipline-${var.customer_name}-emr-service-role"
  }
}

# EMR Service Role Policy - EC2 permissions required for EMR to manage instances
data "aws_iam_policy_document" "emr_service_policy" {
  # EC2 permissions for EMR service
  statement {
    sid    = "EC2Permissions"
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CancelSpotInstanceRequests",
      "ec2:CreateFleet",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateNetworkInterface",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteLaunchTemplate",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteTags",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceTypeOfferings",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeLaunchTemplates",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribePrefixLists",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSpotInstanceRequests",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeSubnets",
      "ec2:DescribeVolumeStatus",
      "ec2:DescribeVolumes",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcEndpoints",
      "ec2:DescribeVpcEndpointServices",
      "ec2:DescribeVpcs",
      "ec2:DetachNetworkInterface",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:RequestSpotInstances",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
    ]
    resources = ["*"]
  }

  # IAM PassRole - scoped to EMR roles
  statement {
    sid    = "IAMPassRole"
    effect = "Allow"
    actions = [
      "iam:CreateServiceLinkedRole",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListInstanceProfiles",
      "iam:ListRolePolicies",
      "iam:PassRole",
    ]
    resources = [
      aws_iam_role.emr_service_role.arn,
      aws_iam_role.emr_profile_role.arn,
      aws_iam_role.emr_autoscaling_role.arn,
      "arn:aws:iam::*:role/aws-service-role/spot.amazonaws.com/AWSServiceRoleForEC2Spot*",
    ]
  }

  # S3 permissions for EMR logs
  statement {
    sid    = "S3LogPermissions"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }

  # CloudWatch permissions
  statement {
    sid    = "CloudWatchPermissions"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:DeleteAlarms",
    ]
    resources = ["*"]
  }

  # Application Auto Scaling
  statement {
    sid    = "AutoScaling"
    effect = "Allow"
    actions = [
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingPolicies",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "emr_service_policy" {
  name   = "zipline-${var.customer_name}-emr-service-policy"
  role   = aws_iam_role.emr_service_role.id
  policy = data.aws_iam_policy_document.emr_service_policy.json
}

# IAM Role for EMR Autoscaling
resource "aws_iam_role" "emr_autoscaling_role" {
  name               = "zipline-${var.customer_name}-emr-autoscaling-role"
  assume_role_policy = data.aws_iam_policy_document.emr_assume_role.json

  tags = {
    Name = "zipline-${var.customer_name}-emr-autoscaling-role"
  }
}

resource "aws_iam_role_policy_attachment" "emr_autoscaling" {
  role       = aws_iam_role.emr_autoscaling_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforAutoScalingRole"
}

# IAM Role for EC2 Instance Profile
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "emr_profile_role" {
  name               = "zipline-${var.customer_name}-emr-profile-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "zipline-${var.customer_name}-emr-profile-role"
  }
}

resource "aws_iam_instance_profile" "emr_profile" {
  name = "zipline-${var.customer_name}-emr-profile"
  role = aws_iam_role.emr_profile_role.name
}

data "aws_iam_policy_document" "emr_profile_policy" {
  # EMR - scoped to cluster
  statement {
    sid    = "EMRDescribe"
    effect = "Allow"
    actions = [
      "elasticmapreduce:Describe*",
      "elasticmapreduce:ListBootstrapActions",
      "elasticmapreduce:ListClusters",
      "elasticmapreduce:ListInstanceGroups",
      "elasticmapreduce:ListInstances",
      "elasticmapreduce:ListSteps",
    ]
    resources = ["*"]
  }

  # CloudWatch - scoped to customer namespace
  statement {
    sid    = "CloudWatchMetrics"
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData",
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Zipline/${var.customer_name}"]
    }
  }

  # DynamoDB - scoped to customer table
  statement {
    sid    = "DynamoDBAccess"
    effect = "Allow"
    actions = [
      "dynamodb:DescribeTable",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
    ]
    resources = [
      aws_dynamodb_table.chronon_metadata.arn,
    ]
  }

  # Glue - scoped to customer databases/tables
  statement {
    sid    = "GlueAccess"
    effect = "Allow"
    actions = [
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
      "glue:UpdateTable",
      "glue:UpdateDatabase",
      "glue:UpdatePartition",
    ]
    resources = [
      "arn:aws:glue:${var.region}:*:catalog",
      "arn:aws:glue:${var.region}:*:database/zipline_${var.customer_name}*",
      "arn:aws:glue:${var.region}:*:table/zipline_${var.customer_name}*/*",
    ]
  }

  # S3 - scoped to customer buckets
  statement {
    sid    = "S3Access"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:ListBucket",
      "s3:PutObject",
    ]
    resources = [
      aws_s3_bucket.warehouse.arn,
      "${aws_s3_bucket.warehouse.arn}/*",
      aws_s3_bucket.logs.arn,
      "${aws_s3_bucket.logs.arn}/*",
    ]
  }
}

resource "aws_iam_role_policy" "emr_profile_policy" {
  name   = "zipline-${var.customer_name}-emr-profile-policy"
  role   = aws_iam_role.emr_profile_role.id
  policy = data.aws_iam_policy_document.emr_profile_policy.json
}
