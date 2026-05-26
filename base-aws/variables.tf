variable "region" {
  description = "The AWS region to deploy resources in (e.g., us-west-2, us-east-1)."
}

variable "customer_name" {
  description = "Your unique company identifier. Used as a prefix for naming AWS resources."
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

variable "emr_subnetwork" {
  description = "Optional subnet ID for the EMR cluster. If empty, the default VPC subnet is used."
  default     = ""
}

variable "emr_custom_image_version" {
  type        = string
  description = "Optional EMR Serverless custom Docker image tag (e.g. 'v3.3.2-zipline.1'). When non-empty, provisions a sibling EMR Serverless application zipline-emr-<customer_name>-custom-image with imageConfiguration set, and attaches an ECR pull policy (scoped to that app) to the existing repo chronon-emr-<customer_name>-custom-image. The canonical zipline-emr-<customer_name> application is left untouched; opt workflows in by pointing teams.py SPARK_CLUSTER_NAME at the custom-image app. The customer must create the ECR repo and push the matching tag before applying."
  default     = ""
}

variable "emr_log_uri" {
  type        = string
  description = "S3 URI for EMR job logs. Defaults to s3://zipline-logs-{customer_name}/emr/"
  default     = ""
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
}

# Custom domain configuration for HTTPS
variable "ui_domain" {
  type        = string
  description = "Custom domain for the orchestration UI (e.g., zipline.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "hub_domain" {
  type        = string
  description = "Custom domain for the orchestration Hub API (e.g., zipline-hub.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "hub_external_url" {
  type        = string
  description = "Override HUB_BASE_URL directly (e.g., http://my-hub-foo). Use when a custom ALB or proxy sits in front of the nginx ELB and hub_domain is not set."
  default     = ""
}

variable "fetcher_domain" {
  type        = string
  description = "Custom domain for the Chronon fetcher service (e.g., zipline-fetcher.yourcompany.com). Leave empty to use the default load balancer DNS."
  default     = ""
}

variable "eval_domain" {
  type        = string
  description = "Custom domain for eval service"
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

variable "databricks_host" {
  type        = string
  description = "Databricks host for data exploration. Leave empty to skip Databricks integration."
  default     = ""
}

variable "databricks_warehouse" {
  type        = string
  description = "Databricks warehouse for data exploration. Leave empty to skip Databricks integration."
  default     = ""
}

variable "enable_data_explorer" {
  type = bool
  description = "Adds data explorer to the UI with catalogs based on databricks and snowflake integration"
  default = false
}

# Snowflake Open Catalog (Polaris, Iceberg REST) integration (optional)
variable "snowflake_polaris_client_id" {
  type        = string
  description = "Snowflake service principal for Catalog OAuth. Leave empty to skip Snowflake integration."
  sensitive   = true
  default     = ""
}

variable "snowflake_polaris_client_secret" {
  type        = string
  description = "Snowflake service principal client secret for Catalog OAuth. Leave empty to skip Snowflake integration."
  sensitive   = true
  default     = ""
}

variable "snowflake_account" {
  type        = string
  description = "Snowflake account for data exploration. Leave empty to skip Snowflake integration."
  default     = ""
}

variable "polaris_warehouse" {
  type        = string
  description = "Polaris warehouse for data exploration. Leave empty to skip Snowflake integration."
  default     = ""
}

variable "polaris_principal_role" {
  type        = string
  description = "Polaris principal role for data exploration. Leave empty to skip Snowflake integration."
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

variable "dynamodb_replica_regions" {
  type        = list(string)
  description = "Additional AWS regions to replicate DynamoDB tables to using Global Tables v2. Empty disables replication."
  default     = []
}

variable "dynamodb_write_capacity" {
  type        = number
  description = "Write capacity units for DynamoDB tables"
  default     = 10
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
  sensitive   = true
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
  sensitive   = true
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
  sensitive   = true
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

# Optional VPC Import
variable "existing_vpc_id" {
  type        = string
  description = "Optional. ID to existing vpc to attach the resources to"
  default     = ""
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