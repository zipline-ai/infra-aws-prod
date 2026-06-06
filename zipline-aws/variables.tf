variable "region" {
  description = "The AWS region to deploy resources in (e.g., us-west-2, us-east-1)."
}

variable "customer_name" {
  description = "Your unique company identifier. Used as a prefix for naming AWS resources."
}

variable "environment" {
  type        = string
  description = "Optional environment qualifier (e.g. \"canary\", \"prod\"). When set, prepended to customer_name so AWS resources are named like zipline-warehouse-<environment>-<customer_name>. Leave empty for the default single-environment naming."
  default     = ""
}

variable "aws_account_id" {
  type        = string
  description = "Optional AWS account ID this stack must deploy into. When set, terraform fails fast if the resolved AWS credentials point at a different account. Recommended for multi-environment setups so an `AWS_PROFILE` mismatch can't silently mutate the wrong account. Leave empty to skip the check."
  default     = ""
}

variable "artifact_prefix" {
  description = "The S3 URI where Zipline artifacts are stored (e.g., s3://your-zipline-artifacts)."
}

variable "zipline_version" {
  type        = string
  description = "The version of Zipline to deploy. This should correspond to a valid Docker image tag in the Zipline repository."
  default     = "latest"
}

variable "dockerhub_token" {
  type        = string
  description = "Docker Hub access token for ECR Pull Through Cache. This should be provided to you by Zipline."
}

variable "terraform_state_bucket" {
  type        = string
  description = "S3 bucket to store terraform state"
}

variable "terraform_state_file" {
  type        = string
  description = "S3 key to store terraform state"
}

variable "terraform_state_region" {
  type        = string
  description = "AWS region to store terraform state"
}

variable "personnel_arns" {
  type        = list(string)
  description = "List of IAM principal ARNs (users or roles) who should have admin access to the EKS cluster and other resources."
  default     = []
}

# EKS Configuration
variable "deploy_fetcher" {
  description = "Whether or not to deploy the fetcher service"
  default     = false
}

variable "fetcher_replicas" {
  type        = number
  description = "Number of fetcher replicas"
  default     = 3
}

variable "eks_version" {
  type        = string
  description = "Kubernetes version for EKS cluster"
  default     = "1.31"
}

variable "in_cluster_compute_enabled" {
  type        = bool
  description = "Single gate for in-cluster Spark compute. When true: TF provisions the spark/flink IRSA + helm release values, the chart renders zipline-default namespace + RBAC + ResourceQuotas + spark-operator + history server + Loki, and the orchestration Hub emits IN_CLUSTER_COMPUTE_ENABLED=true so its AWSWorkflowExecutionVerticle routes through K8sSubmitter instead of EmrServerlessSubmitter. When false: orchestration Hub uses EMR Serverless (default) and the chart skips the compute section entirely."
  default     = false
}

variable "spark_compute_namespace" {
  type        = string
  description = "Initial Kubernetes namespace for in-cluster Zipline Spark compute jobs."
  default     = "zipline-default"
}

variable "spark_compute_image_registry" {
  type        = string
  description = "Optional private registry prefix containing Zipline Spark compute images mirrored by zipline admin install."
  default     = ""
  nullable    = false
}

variable "spark_compute_image" {
  type        = string
  description = "Optional Spark image override for Kubernetes compute jobs."
  default     = null
  nullable    = true
}

# Custom domains for HTTPS (optional)
variable "ui_domain" {
  description = "Custom domain for the orchestration UI (e.g., zipline.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "hub_domain" {
  description = "Custom domain for the orchestration Hub API (e.g., zipline-hub.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "hub_external_url" {
  description = "Override HUB_BASE_URL directly (e.g., http://my-hub-foo). Use when a custom ALB or proxy sits in front of the nginx ELB and hub_domain is not set."
  default     = ""
}

variable "fetcher_domain" {
  description = "Custom domain for the Chronon fetcher service (e.g., zipline-fetcher.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "eval_domain" {
  description = "Custom domain for the Chronon eval service (e.g., zipline-eval.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "ui_cert_arn" {
  type        = string
  description = "ARN of an existing ACM certificate for the orchestration UI domain. Leave empty to create a certificate when ui_domain is set."
  default     = ""
}

variable "hub_cert_arn" {
  type        = string
  description = "ARN of an existing ACM certificate for the orchestration Hub API domain. Leave empty to create a certificate when hub_domain is set."
  default     = ""
}

variable "fetcher_cert_arn" {
  type        = string
  description = "ARN of an existing ACM certificate for the Chronon fetcher domain. Leave empty to create a certificate when fetcher_domain is set."
  default     = ""
}

variable "eval_cert_arn" {
  type        = string
  description = "ARN of an existing ACM certificate for the Chronon eval domain. Leave empty to create a certificate when eval_domain is set."
  default     = ""
}

# Glue Schema Registry (optional)
variable "glue_schema_registry_name" {
  type        = string
  description = "Name of an existing Glue Schema Registry for Flink streaming jobs. Leave empty to create a new one named zipline-{customer_name}."
  default     = ""
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

variable "emr_custom_image_version" {
  type        = string
  description = "Optional EMR Serverless custom Docker image tag (e.g. 'v3.3.2-zipline.1'). When non-empty, provisions a sibling EMR Serverless application zipline-emr-<customer_name>-custom-image with imageConfiguration set, and attaches an ECR pull policy (scoped to that app) to the existing repo chronon-emr-<customer_name>-custom-image. The canonical zipline-emr-<customer_name> application is left untouched; opt workflows in by pointing teams.py SPARK_CLUSTER_NAME at the custom-image app. The customer must create the ECR repo and push the matching tag before applying."
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

variable "additional_data_buckets" {
  type        = list(string)
  description = "Additional S3 bucket names (without arn prefix) to grant the orchestration IRSA read-only access to. Use this for external data lake buckets (e.g. Iceberg metadata paths) that the orchestration role needs to read."
  default     = []
}

variable "create_ecr_pullthroughcache_resources" {
  type        = bool
  description = "Whether to create ECR Pull Through Cache resources. Account-level globals — a second zipline-aws deployment in the same AWS account must set this to false to avoid colliding with the first stack's ecr-pullthroughcache/dockerhub secret and zipline-private/ cache rule. EKS nodes still pull Docker Hub images directly via the kubernetes docker-hub-creds secret."
  default     = true
}

# DynamoDB Configuration
variable "dynamodb_table_prefix" {
  type        = string
  description = "Prefix to prepend to DynamoDB table names (CHRONON_METADATA and TABLE_PARTITIONS). Leave empty for no prefix."
  default     = ""
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

variable "dynamodb_replica_regions" {
  type        = list(string)
  description = "Additional AWS regions to replicate DynamoDB tables to using Global Tables v2. Empty disables replication."
  default     = []

  validation {
    condition     = length(var.dynamodb_replica_regions) == length(distinct(var.dynamodb_replica_regions)) && alltrue([for r in var.dynamodb_replica_regions : r != ""])
    error_message = "dynamodb_replica_regions must contain only unique, non-empty region strings."
  }
}

# Zipline Authentication
variable "zipline_auth_enabled" {
  type        = bool
  description = "Enable Zipline authentication"
  default     = false
}

variable "google_oauth_client_id" {
  type        = string
  description = "Optional for use google oauth with zipline authentication"
  default     = ""
}

variable "google_oauth_client_secret" {
  type        = string
  description = "Optional for use google oauth with zipline authentication"
  default     = ""
}

variable "github_oauth_client_id" {
  type        = string
  description = "Optional for use github oauth with zipline authentication"
  default     = ""
}

variable "github_oauth_client_secret" {
  type        = string
  description = "Optional for use github oauth with zipline authentication"
  default     = ""
}

variable "microsoft_entra_tenant_id" {
  type        = string
  description = "Optional for use Microsoft Entra id with zipline authentication"
  default     = ""
}

variable "microsoft_entra_oauth_client_id" {
  type        = string
  description = "Optional for use Microsoft Entra id with zipline authentication"
  default     = ""
}


variable "microsoft_entra_oauth_client_secret" {
  type        = string
  description = "Optional for use microsoft Entra ID with zipline authentication"
  default     = ""
}

variable "sso_provider_id" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_domain" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_issuer" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_client_id" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
}

variable "sso_client_secret" {
  type        = string
  description = "Optional for use SSO with zipline authentication"
  default     = ""
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

# Optional VPC Import
# If used, S3 and DynamoDB Gateway endpoints are required for EMR Serverless workers (they lack public IPs).
# Users providing an existing VPC must ensure these endpoints exist.

variable "existing_vpc_id" {
  type        = string
  description = "Optional. ID to existing vpc to attach the resources to"
  default     = ""

  validation {
    condition     = var.existing_vpc_id == "" || (var.existing_vpc_primary_subnet_id != "" && var.existing_vpc_secondary_subnet_id != "")
    error_message = "When existing_vpc_id is provided, both existing_vpc_primary_subnet_id and existing_vpc_secondary_subnet_id must also be provided."
  }
}

variable "existing_vpc_primary_subnet_id" {
  type        = string
  description = "Optional. ID to existing primary subnet to attach the resources to"
  default     = ""
}

variable "existing_vpc_secondary_subnet_id" {
  type        = string
  description = "Optional. ID to existing secondary subnet to attach the resources to"
  default     = ""
}

# Encryption
variable "encrypt_at_rest" {
  type        = bool
  description = "Whether to encrypt data at rest in rds"
  default     = false
}

variable "encryption_kms_key_arn" {
  type        = string
  description = "Optional customer managed KMS key ARN to use for at-rest encryption. Leave empty to use AWS managed service keys."
  default     = ""
}

variable "encryption_kms_key_arns" {
  type        = map(string)
  description = "Optional customer managed KMS key ARNs keyed by region for resources that support per-region keys, such as DynamoDB replicas."
  default     = {}
}
