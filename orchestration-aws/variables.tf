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
  default     = "1.31"
}

variable "eks_instance_type" {
  type        = string
  description = "Instance type for EKS node group"
  default     = "m5.2xlarge"
}

variable "eks_desired_size" {
  type        = number
  description = "Desired number of nodes in EKS node group"
  default     = 3
}

variable "eks_min_size" {
  type        = number
  description = "Minimum number of nodes in EKS node group"
  default     = 1
}

variable "eks_max_size" {
  type        = number
  description = "Maximum number of nodes in EKS node group"
  default     = 5
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

variable "dynamodb_table_name" {
  type        = string
  description = "Name of the DynamoDB table for Chronon metadata"
  default     = "CHRONON_METADATA"
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
