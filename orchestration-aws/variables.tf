variable "dockerhub_token" {
  type        = string
  description = "Docker Hub access token for ECR Pull Through Cache. This should be provided to you by Zipline."
}

variable "zipline_version" {
  type        = string
  description = "The version of Zipline to deploy. This should correspond to a valid Docker image tag in the Zipline repository."
  default     = "latest"
}

variable "name_prefix" {
  description = "Prefix used for naming AWS resources. Typically matches customer_name."
}

variable "artifact_prefix" {
  type        = string
  description = "The S3 URI where Zipline artifacts are stored (e.g., s3://your-zipline-artifacts)."
}

variable "security_group_id" {
  type        = string
  description = "The security group ID to attach to resources."
}

variable "main_subnet_id" {
  type        = string
  description = "The primary subnet ID to deploy resources into."
}

variable "secondary_subnet_id" {
  type        = string
  description = "The secondary subnet ID for multi-AZ deployments."
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID where EKS cluster will be deployed."
}

variable "warehouse_bucket" {
  type        = string
  description = "Name of the S3 warehouse bucket for artifacts."
}

# EKS Configuration
variable "eks_version" {
  type        = string
  description = "Kubernetes version for EKS cluster"
}

variable "eks_instance_type" {
  type        = string
  description = "Instance type for EKS node group"
  default     = "m8a.4xlarge"
}

variable "fetcher_replicas" {
  type        = number
  description = "Number of fetcher replicas"
  default     = 3
}

variable "eks_desired_size" {
  type        = number
  description = "Desired number of nodes in EKS node group"
  default     = 3
}

variable "eks_min_size" {
  type        = number
  description = "Minimum number of nodes in EKS node group"
  default     = 3
}

variable "eks_max_size" {
  type        = number
  description = "Maximum number of nodes in EKS node group"
  default     = 8
}

variable "eks_disk_size" {
  type        = number
  description = "Disk size in GB for EKS nodes"
  default     = 100
}

# Domain Configuration (optional)
variable "hub_domain" {
  type        = string
  description = "Custom domain for orchestration hub (e.g., zipline-hub.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "hub_external_url" {
  type        = string
  description = "Override HUB_BASE_URL directly (e.g., http://my-hub-foo). Use when a custom ALB or proxy sits in front of the nginx ELB and hub_domain is not set."
  default     = ""
}

variable "ui_domain" {
  type        = string
  description = "Custom domain for orchestration UI (e.g., zipline.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "fetcher_domain" {
  type        = string
  description = "Custom domain for Chronon fetcher service (optional)"
  default     = ""
}

variable "eval_domain" {
  type        = string
  description = "Custom domain for eval service (optional)"
  default     = ""
}

variable "dynamodb_table_prefix" {
  type        = string
  description = "Prefix to prepend to DynamoDB table names (CHRONON_METADATA and TABLE_PARTITIONS). Leave empty for no prefix."
  default     = ""
}

variable "dynamodb_enable_ttl" {
  type        = bool
  description = "Enable TTL on DynamoDB KV store tables and batch-imported tables. Set to false to disable TTL-based data expiry."
  default     = true
}

variable "dynamodb_read_capacity" {
  type        = number
  description = "Read capacity units for DynamoDB tables"
  default     = 10
}

variable "dynamodb_write_capacity" {
  type        = number
  description = "Write capacity units for DynamoDB tables"
  default     = 10
}

variable "glue_schema_registry_name" {
  type        = string
  description = "Name of an existing Glue Schema Registry for Flink streaming jobs. Leave empty to create a new one named zipline-{customer_name}."
  default     = ""
}

variable "msk_cluster_arn" {
  type        = string
  description = "ARN of the MSK cluster for Flink IAM access. Leave empty to skip MSK permissions."
  default     = ""
}

variable "additional_flink_s3_buckets" {
  type        = list(string)
  description = "Additional S3 bucket names (without arn prefix) to grant the Flink job execution role read/write access to. Useful for cross-account artifact prefixes that aren't covered by warehouse_bucket or artifact_prefix."
  default     = []
}

variable "personnel_arns" {
  type        = list(string)
  description = "List of IAM principal ARNs (users or roles) who should have admin access to the EKS cluster."
  default     = []
}

# EMR Serverless configuration
variable "emr_log_uri" {
  type        = string
  description = "S3 URI for EMR job logs. Defaults to s3://zipline-logs-{name_prefix}/emr/"
  default     = ""
}

variable "emr_cloudwatch_log_group" {
  type        = string
  description = "CloudWatch log group name for EMR Serverless job logs"
}

# Databricks Unity Catalog integration (optional)
variable "databricks_client_id" {
  type        = string
  description = "Databricks service principal Application ID (UUID) for Unity Catalog OAuth. Leave empty to skip Databricks integration."
  sensitive   = true
  default     = ""
}

variable "databricks_client_secret" {
  type        = string
  description = "Databricks service principal client secret for Unity Catalog OAuth. Leave empty to skip Databricks integration."
  sensitive   = true
  default     = ""
}

# Zipline Authentication
variable "zipline_auth_enabled" {
  type        = bool
  description = "Enable Zipline authentication"
  default     = false
}

variable "google_oauth_client_id" {
  type        = string
  description = "Optional for using google oauth with zipline authentication"
  default     = ""
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Optional for using google oauth with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "github_oauth_client_id" {
  type        = string
  description = "Optional for using github oauth with zipline authentication"
  default     = ""
}

variable "github_oauth_client_secret" {
  type        = string
  description = "Optional for using github oauth with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "microsoft_entra_tenant_id" {
  type        = string
  description = "Optional for using Microsoft Entra id with zipline authentication"
  default     = ""
}

variable "microsoft_entra_oauth_client_id" {
  type        = string
  description = "Optional for using Microsoft Entra id with zipline authentication"
  default     = ""
}


variable "microsoft_entra_oauth_client_secret" {
  type        = string
  description = "Optional for using microsoft Entra ID with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "sso_provider_id" {
  type        = string
  description = "Optional for using SSO with zipline authentication"
  default     = ""
}

variable "sso_domain" {
  type        = string
  description = "Optional for using SSO with zipline authentication"
  default     = ""
}

variable "sso_issuer" {
  type        = string
  description = "Optional for using SSO with zipline authentication"
  default     = ""
}

variable "sso_client_id" {
  type        = string
  description = "Optional for using SSO with zipline authentication"
  default     = ""
}

variable "sso_client_secret" {
  type        = string
  description = "Optional for using SSO with zipline authentication"
  default     = ""
  sensitive   = true
}

variable "idp_role_mapping" {
  type        = string
  description = "Optional comma separated list of role mappings for zipline authentication"
  default     = ""
}

variable "idp_group_claim" {
  type        = string
  description = "Optional group claims configured for zipline authentication"
  default     = ""
}