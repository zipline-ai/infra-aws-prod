# EKS Cluster for Zipline Orchestration

# EKS Cluster IAM Role
data "aws_iam_policy_document" "eks_cluster_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "${var.name_prefix}-eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json

  tags = {
    Name = "${var.name_prefix}-eks-cluster-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Cluster Security Group
resource "aws_security_group" "eks_cluster" {
  name        = "${var.name_prefix}-eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-eks-cluster-sg"
  }
}

resource "aws_security_group_rule" "eks_cluster_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.eks_cluster.id
  description       = "Allow HTTPS access to EKS API server"
}

# Allow EKS nodes to access RDS PostgreSQL
# Uses the EKS-managed cluster security group (assigned to nodes)
resource "aws_security_group_rule" "eks_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  security_group_id        = var.security_group_id
  description              = "Allow EKS nodes to access RDS PostgreSQL"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "${var.name_prefix}-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = [var.main_subnet_id, var.secondary_subnet_id]
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [aws_security_group.eks_cluster.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = "${var.name_prefix}-eks"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# EKS Access Entries for personnel
resource "aws_eks_access_entry" "personnel" {
  for_each = toset(var.personnel_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "personnel_cluster_admin" {
  for_each = toset(var.personnel_arns)

  cluster_name  = aws_eks_cluster.main.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.personnel]
}

# EKS Node Group IAM Role
data "aws_iam_policy_document" "eks_node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "${var.name_prefix}-eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume_role.json

  tags = {
    Name = "${var.name_prefix}-eks-node-role"
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}

# EMR permissions for EKS nodes
data "aws_iam_policy_document" "eks_node_emr_policy" {
  statement {
    effect = "Allow"
    actions = [
      "elasticmapreduce:RunJobFlow",
      "elasticmapreduce:ListClusters",
      "elasticmapreduce:DescribeCluster",
      "elasticmapreduce:AddJobFlowSteps",
      "elasticmapreduce:DescribeStep",
      "elasticmapreduce:CancelSteps",
      "elasticmapreduce:ListSteps",
      "elasticmapreduce:TerminateJobFlows",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/zipline_${var.name_prefix}_emr_service_role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/zipline_${var.name_prefix}_emr_profile_role",
    ]
  }

  # S3 permissions for uploading job metadata
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${var.warehouse_bucket}",
      "arn:aws:s3:::${var.warehouse_bucket}/*",
    ]
  }

  # KMS permissions in case encryption is required by organization
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "eks_node_emr" {
  name   = "${var.name_prefix}-eks-node-emr"
  role   = aws_iam_role.eks_node_role.id
  policy = data.aws_iam_policy_document.eks_node_emr_policy.json
}

# KMS Key for EKS node root volume encryption
data "aws_iam_policy_document" "eks_node_root_key_policy" {
  statement {
    sid    = "Enable IAM User Permissions"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "Allow EKS service to create grants for EBS"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.eks_cluster_role.arn]
    }
    actions = ["kms:CreateGrant"]
    resources = ["*"]
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    sid    = "Allow use by the EC2 Auto Scaling service-linked role"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
      "kms:CreateGrant"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "Allow EKS node role to use the key for EBS"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.eks_node_role.arn]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey"
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "eks_node_root" {
  description             = "KMS key for EKS node root volume encryption"
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.eks_node_root_key_policy.json

  tags = {
    Name = "${var.name_prefix}-eks-node-root-key"
  }
}

# Launch template for EKS nodes with encrypted root volume
resource "aws_launch_template" "eks_nodes" {
  name_prefix = "${var.name_prefix}-eks-nodes"
  description = "Launch template for EKS nodes with encrypted root volume"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = var.eks_disk_size
      volume_type = "gp3"
      encrypted   = true
      kms_key_id  = aws_kms_key.eks_node_root.arn
    }
  }

  tag_specifications {
    resource_type = "volume"
    tags = {
      Name = "${var.name_prefix}-eks-node-root-volume"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EKS Node Group
resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.name_prefix}-default"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = [var.main_subnet_id, var.secondary_subnet_id]
  instance_types  = [var.eks_instance_type]

  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  scaling_config {
    desired_size = var.eks_desired_size
    max_size     = var.eks_max_size
    min_size     = var.eks_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "zipline-workload"
  }

  tags = {
    Name = "${var.name_prefix}-eks-node"
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
    aws_iam_role_policy.eks_node_emr,
    aws_kms_key.eks_node_root,
  ]
}

# OIDC Provider for IRSA
data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.name_prefix}-eks-oidc"
  }
}

# Create zipline-system namespace
resource "kubernetes_namespace_v1" "zipline_system" {
  metadata {
    name = "zipline-system"
  }

  depends_on = [aws_eks_node_group.default]
}

# Create zipline-flink namespace for Flink jobs
resource "kubernetes_namespace_v1" "zipline_flink" {
  metadata {
    name = "zipline-flink"
  }

  depends_on = [aws_eks_node_group.default]
}

# Docker Hub credentials secret for Kubernetes
resource "kubernetes_secret_v1" "docker_hub_creds" {
  metadata {
    name      = "docker-hub-creds"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "https://index.docker.io/v1/" = {
          username = "ziplineai"
          password = var.dockerhub_token
          auth     = base64encode("ziplineai:${var.dockerhub_token}")
        }
      }
    })
  }
}

# AWS Load Balancer Controller IAM Role
data "aws_iam_policy_document" "aws_lb_controller_assume_role" {
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
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "aws_lb_controller" {
  name               = "${var.name_prefix}-aws-lb-controller"
  assume_role_policy = data.aws_iam_policy_document.aws_lb_controller_assume_role.json

  tags = {
    Name = "${var.name_prefix}-aws-lb-controller"
  }
}

resource "aws_iam_role_policy_attachment" "aws_lb_controller" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.aws_lb_controller.name
}

# Additional policy for AWS LB Controller
data "aws_iam_policy_document" "aws_lb_controller_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeVpcs",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeInstances",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeTags",
      "ec2:GetCoipPoolUsage",
      "ec2:DescribeCoipPools",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeListenerCertificates",
      "elasticloadbalancing:DescribeSSLPolicies",
      "elasticloadbalancing:DescribeRules",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetHealth",
      "elasticloadbalancing:DescribeTags",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "cognito-idp:DescribeUserPoolClient",
      "acm:ListCertificates",
      "acm:DescribeCertificate",
      "iam:ListServerCertificates",
      "iam:GetServerCertificate",
      "waf-regional:GetWebACL",
      "waf-regional:GetWebACLForResource",
      "waf-regional:AssociateWebACL",
      "waf-regional:DisassociateWebACL",
      "wafv2:GetWebACL",
      "wafv2:GetWebACLForResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
      "shield:GetSubscriptionState",
      "shield:DescribeProtection",
      "shield:CreateProtection",
      "shield:DeleteProtection",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:DeleteSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:ModifyRule",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "aws_lb_controller_policy" {
  name   = "${var.name_prefix}-aws-lb-controller-policy"
  role   = aws_iam_role.aws_lb_controller.id
  policy = data.aws_iam_policy_document.aws_lb_controller_policy.json
}

# CloudWatch Logs IAM Policy for Fluent Bit
data "aws_iam_policy_document" "fluent_bit_cloudwatch" {
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
}

resource "aws_iam_role_policy" "eks_node_cloudwatch" {
  name   = "${var.name_prefix}-eks-node-cloudwatch"
  role   = aws_iam_role.eks_node_role.id
  policy = data.aws_iam_policy_document.fluent_bit_cloudwatch.json
}

# Fluent Bit for container logging to CloudWatch
# To upgrade to full metrics later, replace this with:
#   aws_eks_addon "cloudwatch_observability" { addon_name = "amazon-cloudwatch-observability" }
resource "helm_release" "fluent_bit" {
  name       = "fluent-bit"
  repository = "https://fluent.github.io/helm-charts"
  chart      = "fluent-bit"
  namespace  = "kube-system"
  version    = "0.43.0"

  values = [<<-EOT
config:
  outputs: |
    [OUTPUT]
        Name              cloudwatch_logs
        Match             *
        region            ${data.aws_region.current.name}
        log_group_name    /aws/eks/${var.name_prefix}-eks/containers
        log_stream_prefix from-fluent-bit-
        auto_create_group true
EOT
  ]

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy.eks_node_cloudwatch,
  ]
}

# Install AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  set {
    name  = "clusterName"
    value = aws_eks_cluster.main.name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.aws_lb_controller.arn
  }

  set {
    name  = "region"
    value = data.aws_region.current.name
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  depends_on = [
    aws_eks_node_group.default,
    aws_iam_role_policy.aws_lb_controller_policy,
  ]
}
