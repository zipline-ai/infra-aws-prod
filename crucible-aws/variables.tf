###############################################################################
# Customer-facing inputs for crucible-aws.
#
# The skeleton is opinionated by design — knobs that don't need to differ
# between deployments are hardcoded in the resource blocks instead of exposed
# here. Each variable below either has a sensible default that works everywhere
# or is required because the value is genuinely environment-specific.
###############################################################################

variable "region" {
  description = "AWS region hosting the cluster."
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name."
  type        = string
  default     = "crucible-eks"
}

variable "eks_version" {
  description = "EKS control-plane version."
  type        = string
  default     = "1.34"
}

# Shared network. Prefer direct IDs when this module is wired into the larger
# Zipline stack. Tags remain supported for standalone installs.
variable "shared_vpc_id" {
  description = "Optional VPC ID that the cluster joins. When set, shared_vpc_name_tag is ignored."
  type        = string
  default     = ""
}

variable "shared_vpc_name_tag" {
  description = "Name tag of the VPC that the cluster joins when shared_vpc_id is not set."
  type        = string
  default     = ""
}

variable "shared_subnet_ids" {
  description = "Optional subnet IDs to attach to the cluster. When set, shared_subnet_name_tags is ignored."
  type        = list(string)
  default     = []
}

variable "shared_subnet_name_tags" {
  description = "Name tags of the subnets to attach to the cluster when shared_subnet_ids is not set. Order is not significant."
  type        = list(string)
  default     = []
}

variable "ingress_nlb_subnet_ids" {
  description = "Optional public subnet IDs where the internet-facing nginx ingress NLB should be provisioned. When set, ingress_nlb_subnet_name_tags is ignored."
  type        = list(string)
  default     = []
}

variable "ingress_nlb_subnet_name_tags" {
  description = "Optional Name tags of public subnets where the internet-facing nginx ingress NLB should be provisioned when ingress_nlb_subnet_ids is not set."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for tag in var.ingress_nlb_subnet_name_tags : trimspace(tag) != ""])
    error_message = "ingress_nlb_subnet_name_tags must not contain empty subnet name tags."
  }

  validation {
    condition     = length(var.ingress_nlb_subnet_name_tags) == length(distinct(var.ingress_nlb_subnet_name_tags))
    error_message = "ingress_nlb_subnet_name_tags must contain unique subnet name tags."
  }
}

variable "node_instance_types" {
  description = "EC2 instance types for the default data-plane node group. Defaults to a single Graviton (arm64) type. Add equivalent-size types to let EKS fall back across instance families when one is capacity-constrained in an AZ — keep every entry the same vCPU/memory size so the cluster autoscaler can predict node capacity. Note: changing this on an existing node group forces a replacement."
  type        = list(string)
  default     = ["m7g.large"]
}

variable "node_min_size" {
  description = "Minimum number of nodes in the default node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the default node group."
  type        = number
  default     = 15
}

variable "node_desired_size" {
  description = "Desired number of nodes in the default node group at apply time."
  type        = number
  default     = 2
}

variable "control_node_instance_types" {
  description = "EC2 instance types for the tainted control-plane node group that runs Hub, ingress, and Crucible control-plane services. Defaults to a single Graviton (arm64) type. Add equivalent-size types for EKS instance-family fallback on AZ capacity — keep every entry the same vCPU/memory size. Note: changing this on an existing node group forces a replacement."
  type        = list(string)
  default     = ["m7g.large"]
}

variable "control_node_min_size" {
  description = "Minimum number of nodes in the tainted control-plane node group."
  type        = number
  default     = 2
}

variable "control_node_max_size" {
  description = "Maximum number of nodes in the tainted control-plane node group."
  type        = number
  default     = 3
}

variable "control_node_desired_size" {
  description = "Desired number of nodes in the tainted control-plane node group at apply time."
  type        = number
  default     = 2
}

variable "personnel_arns" {
  description = "IAM principal ARNs that should get cluster admin access via EKS access entries."
  type        = list(string)
  default     = []
}

variable "crucible_bucket_name" {
  description = "S3 bucket for Crucible spark event logs, flink checkpoints, and jar staging."
  type        = string
}

variable "public_host" {
  description = "Public hostname for the cluster. ACM cert is issued for this exact domain."
  type        = string
}

variable "job_namespace" {
  description = "Kubernetes namespace where Crucible submits Spark and Flink jobs."
  type        = string
  default     = "crucible-jobs"

  validation {
    condition     = trimspace(var.job_namespace) != ""
    error_message = "job_namespace must not be empty."
  }
}

variable "crucible_chart_values_files" {
  description = "Optional Helm values files, relative to crucible-aws/, merged after the Terraform-generated AWS defaults for the Crucible release."
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for path in var.crucible_chart_values_files :
      !startswith(path, "/") && !strcontains(path, "..") && trimspace(path) != ""
    ])
    error_message = "crucible_chart_values_files must contain non-empty relative paths under crucible-aws/."
  }
}

# EKS API server exposure. Empty list → endpoint is private-only (the secure
# default — operators reach it through the VPC). Non-empty list → endpoint is
# public and restricted to those CIDRs. Customers who need kubectl from
# outside the VPC supply their operator/CI CIDRs here.
variable "eks_public_access_cidrs" {
  description = "CIDR ranges allowed to reach the EKS API server. Empty disables the public endpoint entirely."
  type        = list(string)
  default     = []
}

# chronon backfill IRSA grants on the spark role. Both lists empty → no
# chronon policy attached; the spark role only gets the cluster's own bucket.
# Otherwise the policy auto-attaches.
variable "chronon_artifact_buckets" {
  description = "S3 buckets the chronon Spark driver needs read-only access to (jar download path + any other read-only inputs)."
  type        = list(string)
  default     = []
}

variable "chronon_warehouse_buckets" {
  description = "S3 buckets the chronon Spark driver writes Iceberg table outputs to (granted read+write)."
  type        = list(string)
  default     = []
}
