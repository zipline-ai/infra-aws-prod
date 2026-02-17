resource "aws_emr_cluster" "emr_cluster" {
  name          = "zipline-${var.customer_name}-emr"
  release_label = "emr-7.12.0"
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
      path = bootstrap_action.value
      name = bootstrap_action.key
    }
  }
  tags = var.emr_tags
  master_instance_group {
    instance_type = "m5.xlarge"
    ebs_config {
      size                 = 32
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }
  core_instance_group {
    instance_type = "m5.xlarge"
    ebs_config {
      size                 = 32
      type                 = "gp2"
      volumes_per_instance = 2
    }
  }
  service_role     = aws_iam_role.iam_emr_service_role.arn
  autoscaling_role = aws_iam_role.iam_emr_service_role.arn
  log_uri          = "s3://zipline-warehouse-${var.customer_name}/emr/"
}

resource "aws_emr_managed_scaling_policy" "zipline_scaling" {
  cluster_id = aws_emr_cluster.emr_cluster.id
  compute_limits {
    maximum_capacity_units = 256
    minimum_capacity_units = 1
    unit_type              = "Instances"
  }
}

###
# IAM Role setups
###
# IAM role for EMR Service
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
resource "aws_iam_role" "iam_emr_service_role" {
  name               = "zipline_${var.customer_name}_emr_service_role"
  assume_role_policy = data.aws_iam_policy_document.emr_assume_role.json
}
data "aws_iam_policy_document" "iam_emr_service_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CancelSpotInstanceRequests",
      "ec2:CreateNetworkInterface",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeDhcpOptions",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstances",
      "ec2:DescribeKeyPairs",
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
      "ec2:DetachVolume",
      "ec2:ModifyImageAttribute",
      "ec2:ModifyInstanceAttribute",
      "ec2:RequestSpotInstances",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListInstanceProfiles",
      "iam:ListRolePolicies",
      "iam:PassRole",
    ]
    resources = ["*"]
  }
}
resource "aws_iam_role_policy" "iam_emr_service_policy" {
  name   = "zipline_${var.customer_name}_emr_service_policy"
  role   = aws_iam_role.iam_emr_service_role.id
  policy = data.aws_iam_policy_document.iam_emr_service_policy.json
}

# IAM Role for EC2 Instance Profile
data "aws_iam_policy_document" "emr_ec2_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_emr_profile_role" {
  name               = "zipline_${var.customer_name}_emr_profile_role"
  assume_role_policy = data.aws_iam_policy_document.emr_ec2_assume_role.json
}
resource "aws_iam_instance_profile" "emr_profile" {
  name = "zipline_${var.customer_name}_emr_profile"
  role = aws_iam_role.iam_emr_profile_role.name
}
data "aws_iam_policy_document" "iam_emr_profile_policy" {
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
      // DynamoDB
      "dynamodb:DescribeTable",
      "dynamodb:ListTables",
      "dynamodb:Scan",
      "dynamodb:Query",
      "dynamodb:BatchGetItem",
      "dynamodb:BatchWriteItem",
      "dynamodb:CreateTable",
      "dynamodb:GetRecords",
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
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
      "glue:UpdateTable",
      "glue:UpdateDatabase",
      "glue:UpdatePartition",
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
resource "aws_iam_role_policy" "iam_emr_profile_policy" {
  name   = "zipline_${var.customer_name}_emr_profile_policy"
  role   = aws_iam_role.iam_emr_profile_role.id
  policy = data.aws_iam_policy_document.iam_emr_profile_policy.json
}
