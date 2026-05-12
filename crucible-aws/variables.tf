variable "region" {
  description = "AWS region hosting the Crucible cluster (same region as canary-eks so they can share the VPC)."
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

# VPC + subnets are reused from the canary stack (per user direction). Resolved
# at plan time via data lookups so this module isn't coupled to the canary
# terraform state — only to the resource names that canary already exposes.
variable "shared_vpc_name_tag" {
  description = "Name tag of the VPC that crucible-eks will join (canary VPC)."
  type        = string
  default     = "zipline-canary-vpc"
}

variable "shared_subnet_name_tags" {
  description = "Name tags of the subnets to attach to crucible-eks. Order is not significant."
  type        = list(string)
  default     = ["zipline-canary-subnet-main", "zipline-canary-subnet-secondary"]
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
  description = "IAM principal ARNs that should get cluster admin access via EKS access entries. Defaults to empty; populate with engineers who'll kubectl into the cluster."
  type        = list(string)
  default     = []
}
