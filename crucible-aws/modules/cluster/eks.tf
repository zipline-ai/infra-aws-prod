###############################################################################
# EKS Cluster IAM role
###############################################################################

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

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume_role.json
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

###############################################################################
# EKS cluster security group
###############################################################################

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster-sg"
  description = "Security group for ${var.cluster_name} control plane"
  vpc_id      = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-cluster-sg"
  }
}

resource "aws_security_group_rule" "cluster_ingress_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.cluster.id
  description       = "Allow HTTPS to the EKS API server"
}

###############################################################################
# EKS cluster
###############################################################################

resource "aws_eks_cluster" "crucible" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.eks_version

  vpc_config {
    subnet_ids              = local.subnet_ids
    endpoint_private_access = true
    # Public endpoint only when the operator opts in by supplying a CIDR
    # allow-list. Skeleton default keeps the endpoint private.
    endpoint_public_access = length(var.eks_public_access_cidrs) > 0
    public_access_cidrs    = length(var.eks_public_access_cidrs) > 0 ? var.eks_public_access_cidrs : null
    security_group_ids     = [aws_security_group.cluster.id]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = {
    Name = var.cluster_name
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
    aws_iam_role_policy_attachment.vpc_resource_controller,
  ]
}

resource "aws_eks_access_entry" "personnel" {
  for_each = toset(var.personnel_arns)

  cluster_name  = aws_eks_cluster.crucible.name
  principal_arn = each.value
}

resource "aws_eks_access_policy_association" "personnel_admin" {
  for_each = toset(var.personnel_arns)

  cluster_name  = aws_eks_cluster.crucible.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.personnel]
}

###############################################################################
# OIDC provider — required by IRSA roles in follow-up PRs.
###############################################################################

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.crucible.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "oidc" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.crucible.identity[0].oidc[0].issuer

  tags = {
    Name = "${var.cluster_name}-oidc"
  }
}

###############################################################################
# Node IAM role
###############################################################################

data "aws_iam_policy_document" "node_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node-role"
  assume_role_policy = data.aws_iam_policy_document.node_assume_role.json
}

resource "aws_iam_role_policy_attachment" "worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node.name
}

###############################################################################
# Node groups
###############################################################################

# Small, tainted pool for Hub, ingress, and Crucible control-plane services.
# Spark/Flink jobs do not tolerate this taint, so data-plane bursts cannot evict
# or consume the capacity that keeps the user/API surface alive.
resource "aws_eks_node_group" "control" {
  cluster_name    = aws_eks_cluster.crucible.name
  node_group_name = "${var.cluster_name}-control"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.subnet_ids
  instance_types  = var.control_node_instance_types
  ami_type        = "AL2023_ARM_64_STANDARD"
  capacity_type   = "ON_DEMAND"

  scaling_config {
    desired_size = var.control_node_desired_size
    max_size     = var.control_node_max_size
    min_size     = var.control_node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role           = "crucible-system"
    workload-plane = "control"
  }

  taint {
    key    = "dedicated"
    value  = "crucible-system"
    effect = "NO_SCHEDULE"
  }

  tags = {
    Name = "${var.cluster_name}-control-node"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.container_registry,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

# Default data-plane node group — arm64 (Graviton) to match GCP c4a + AKS arm64 pools.
# Chronon engine Spark/Flink pods are pinned here by the Crucible Helm values.

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.crucible.name
  node_group_name = "${var.cluster_name}-default"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = local.subnet_ids
  instance_types  = var.node_instance_types
  ami_type        = "AL2023_ARM_64_STANDARD"

  scaling_config {
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role           = "crucible-workload"
    workload-plane = "data"
  }

  tags = {
    Name = "${var.cluster_name}-node"
  }

  depends_on = [
    aws_iam_role_policy_attachment.worker_node_policy,
    aws_iam_role_policy_attachment.cni_policy,
    aws_iam_role_policy_attachment.container_registry,
  ]

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
