###############################################################################
# Skeleton variables for crucible-aws.
#
# Environment-specific values (canary VPC/subnet tags, public host, bucket
# name, public-API CIDR list, ...) come from `terraform.tfvars` that lives in
# s3://zipline-canary-vars/crucible/ and is pulled in by `pull_canary_config.sh`
# at plan/apply time — so this template stays env-agnostic and doesn't leak
# canary-account specifics into the prod-facing tree.
#
# Generic operational defaults (region, cluster name, eks version, node sizing)
# stay here as reasonable starting points. Anything specific to *which*
# network or *which* fleet of buckets the cluster talks to has no default —
# missing values fail the plan loudly rather than silently selecting whatever
# happens to share a name in the current account.
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

# EKS public API endpoint exposure.
#
# Skeleton default is private-only — canary `terraform.tfvars` flips this on
# (operator laptops + GitHub Actions OIDC need to reach the API). Prod should
# leave it off, or supply a tight `eks_public_access_cidrs` list.
variable "eks_endpoint_public_access" {
  description = "Whether the EKS API endpoint is reachable from outside the VPC."
  type        = bool
  default     = false
}

variable "eks_public_access_cidrs" {
  description = "CIDR ranges allowed to reach the EKS public API endpoint when eks_endpoint_public_access is true. Empty list means AWS-default (0.0.0.0/0)."
  type        = list(string)
  default     = []
}

# Shared network. Supplied per-environment via tfvars from S3.
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

# Optional chronon backfill grants on the spark IAM role. The shape is the
# same for any chronon-on-EKS deployment (read on artifact + warehouse
# buckets, Glue catalog, DynamoDB tables that BatchNodeRunner writes to);
# the values below are environment-specific and supplied via tfvars.
variable "spark_chronon_grants_enabled" {
  description = "Attach the chronon-grants inline policy to the spark IAM role. Off in the skeleton; canary tfvars enables it."
  type        = bool
  default     = false
}

variable "chronon_artifact_buckets" {
  description = "S3 buckets the chronon Spark driver downloads its cloud_aws jar from (typically ARTIFACT_PREFIX in chronon/python/test/canary/teams.py)."
  type        = list(string)
  default     = []
}

variable "chronon_warehouse_read_buckets" {
  description = "S3 buckets the chronon Spark driver needs read access to (warehouse / spark-libs / Iceberg metadata reads)."
  type        = list(string)
  default     = []
}

variable "chronon_warehouse_write_buckets" {
  description = "S3 buckets the chronon Spark driver writes Iceberg table outputs to."
  type        = list(string)
  default     = []
}

variable "chronon_dynamodb_account" {
  description = "AWS account ID that holds the chronon DynamoDB tables. Empty = current account."
  type        = string
  default     = ""
}
