# Karpenter NodePool and EC2NodeClass Configuration
# This file defines how Karpenter provisions nodes for Flink workloads

# EC2NodeClass - defines the node template
resource "kubectl_manifest" "karpenter_ec2nodeclass" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.k8s.aws/v1"
    kind       = "EC2NodeClass"
    metadata = {
      name = "flink-workload"
    }
    spec = {
      amiSelectorTerms = [
        {
          alias = "al2023@latest"
        }
      ]
      role = aws_iam_role.karpenter_node.name
      subnetSelectorTerms = [
        {
          id = var.main_subnet_id
        },
        {
          id = var.secondary_subnet_id
        }
      ]
      securityGroupSelectorTerms = [
        {
          id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
        }
      ]
      userData = base64encode(<<-EOT
        #!/bin/bash
        # Bootstrap script for Karpenter-provisioned nodes
        /etc/eks/bootstrap.sh ${aws_eks_cluster.main.name}
      EOT
      )
      blockDeviceMappings = [
        {
          deviceName = "/dev/xvda"
          ebs = {
            volumeSize          = "${var.eks_disk_size}Gi"
            volumeType          = "gp3"
            encrypted           = true
            kmsKeyID            = aws_kms_key.eks_node_root.arn
            deleteOnTermination = true
          }
        }
      ]
      metadataOptions = {
        httpEndpoint            = "enabled"
        httpProtocolIPv6        = "disabled"
        httpPutResponseHopLimit = 2
        httpTokens              = "required"
      }
      tags = {
        Name                                        = "${var.name_prefix}-karpenter-node"
        "karpenter.sh/discovery"                    = aws_eks_cluster.main.name
        "eks:eks-cluster-name"                      = aws_eks_cluster.main.name
        "karpenter.k8s.aws/ec2nodeclass"           = "flink-workload"
      }
    }
  })

  depends_on = [
    helm_release.karpenter,
    aws_iam_role.karpenter_node,
  ]
}

# NodePool for Flink workloads - supports both on-demand and spot
resource "kubectl_manifest" "karpenter_nodepool_flink" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "flink-workload"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type"       = "flink"
            "role"                = "zipline-workload"
            "karpenter.sh/nodepool" = "flink-workload"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "flink-workload"
          }
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot", "on-demand"]
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["c", "m", "r"]  # Compute, general purpose, memory optimized
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["4"]  # Only use generation 5 and newer
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["large", "xlarge", "2xlarge", "4xlarge", "8xlarge"]
            }
          ]
          taints = []
        }
      }
      limits = {
        cpu    = "1000"
        memory = "1000Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "1m"
        budgets = [
          {
            nodes = "10%"
          }
        ]
      }
      weight = 10
    }
  })

  depends_on = [
    kubectl_manifest.karpenter_ec2nodeclass,
  ]
}

# NodePool for system workloads (lower priority, cost-optimized)
resource "kubectl_manifest" "karpenter_nodepool_system" {
  yaml_body = yamlencode({
    apiVersion = "karpenter.sh/v1"
    kind       = "NodePool"
    metadata = {
      name = "system-workload"
    }
    spec = {
      template = {
        metadata = {
          labels = {
            "workload-type"       = "system"
            "role"                = "zipline-workload"
            "karpenter.sh/nodepool" = "system-workload"
          }
        }
        spec = {
          nodeClassRef = {
            group = "karpenter.k8s.aws"
            kind  = "EC2NodeClass"
            name  = "flink-workload"
          }
          requirements = [
            {
              key      = "karpenter.sh/capacity-type"
              operator = "In"
              values   = ["spot"]  # System workloads prefer spot for cost savings
            },
            {
              key      = "kubernetes.io/arch"
              operator = "In"
              values   = ["amd64"]
            },
            {
              key      = "karpenter.k8s.aws/instance-category"
              operator = "In"
              values   = ["t", "c", "m"]  # Burstable and general purpose
            },
            {
              key      = "karpenter.k8s.aws/instance-generation"
              operator = "Gt"
              values   = ["3"]
            },
            {
              key      = "karpenter.k8s.aws/instance-size"
              operator = "In"
              values   = ["medium", "large", "xlarge", "2xlarge"]
            }
          ]
          taints = []
        }
      }
      limits = {
        cpu    = "100"
        memory = "100Gi"
      }
      disruption = {
        consolidationPolicy = "WhenEmptyOrUnderutilized"
        consolidateAfter    = "30s"
        budgets = [
          {
            nodes = "100%"  # More aggressive consolidation for system workloads
          }
        ]
      }
      weight = 1  # Lower priority than flink-workload
    }
  })

  depends_on = [
    kubectl_manifest.karpenter_ec2nodeclass,
  ]
}
