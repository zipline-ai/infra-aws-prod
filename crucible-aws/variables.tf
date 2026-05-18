###############################################################################
# Customer-facing inputs for crucible-aws.
#
# The skeleton is opinionated by design — knobs that don't need to differ
# between our canary and a customer's deployment are hardcoded in the resource
# blocks instead of exposed here. Each variable below either has a sensible
# default that works everywhere, or is required because the value is genuinely
# environment-specific (VPC tag, bucket name, public host).
#
# Concrete values for the required vars live in `terraform.tfvars` pulled from
# `s3://zipline-canary-vars/crucible/` by `./pull_canary_config.sh`.
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

# Shared network. Supplied per-environment via tfvars.
variable "shared_vpc_name_tag" {
  description = "Name tag of the VPC that the cluster joins."
  type        = string
}

variable "shared_subnet_name_tags" {
  description = "Name tags of the subnets to attach to the cluster. Order is not significant."
  type        = list(string)
}

variable "node_instance_type" {
  description = "EC2 instance type for the default node group. Graviton (arm64) keeps cost in line with the GCP c4a / AKS Standard_D4ps_v6 pools."
  type        = string
  default     = "m7g.large"
}

variable "node_min_size" {
  description = "Minimum number of nodes in the default node group."
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of nodes in the default node group."
  type        = number
  default     = 5
}

variable "node_desired_size" {
  description = "Desired number of nodes in the default node group at apply time."
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
