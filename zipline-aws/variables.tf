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

# Optional Crucible deployment
variable "deploy_crucible" {
  type        = bool
  description = "Whether to deploy a separate Crucible EKS cluster alongside the Zipline stack."
  default     = false
}

variable "spark_compute_enabled" {
  type        = bool
  description = "Whether to deploy Spark Kubernetes Operator compute resources into the main Zipline orchestration cluster."
  default     = false
}

variable "spark_compute_namespace" {
  type        = string
  description = "Initial Kubernetes namespace for in-cluster Zipline Spark and Flink compute jobs."
  default     = "zipline-default"
}

variable "crucible_cluster_name" {
  type        = string
  description = "Optional EKS cluster name for Crucible. Defaults to <customer_name>-crucible-eks when deploy_crucible is true."
  default     = ""
}

variable "crucible_bucket_name" {
  type        = string
  description = "Optional S3 bucket name for Crucible spark event logs, flink checkpoints, and jar staging. Defaults to zipline-crucible-<customer_name>."
  default     = ""
}

variable "crucible_public_host" {
  type        = string
  description = "Public hostname for Crucible. Required when deploy_crucible is true; ACM issues a certificate for this exact domain."
  default     = ""
}

variable "crucible_eks_public_access_cidrs" {
  type        = list(string)
  description = "CIDR ranges allowed to reach the Crucible EKS API server. Empty disables the public endpoint."
  default     = []
}

variable "crucible_ingress_nlb_subnet_ids" {
  type        = list(string)
  description = "Optional public subnet IDs for the Crucible nginx ingress NLB. Defaults to the Zipline stack subnets."
  default     = []
}

variable "crucible_job_namespace" {
  type        = string
  description = "Kubernetes namespace where Crucible submits Spark and Flink jobs."
  default     = "crucible-jobs"

  validation {
    condition     = trimspace(var.crucible_job_namespace) != ""
    error_message = "crucible_job_namespace must not be empty."
  }
}

variable "crucible_gateway_image_repository" {
  type        = string
  description = "Gateway image repository for the Platform-owned Crucible Helm chart."
  default     = "us-docker.pkg.dev/crucible-io/crucible/gateway"
}

variable "crucible_gateway_image_tag" {
  type        = string
  description = "Optional gateway image tag. Empty lets the Crucible Helm chart use its appVersion."
  default     = ""
  nullable    = false
}

variable "crucible_gateway_image_pull_policy" {
  type        = string
  description = "Image pull policy for the Crucible gateway."
  default     = "IfNotPresent"

  validation {
    condition     = contains(["Always", "IfNotPresent", "Never"], var.crucible_gateway_image_pull_policy)
    error_message = "crucible_gateway_image_pull_policy must be Always, IfNotPresent, or Never."
  }
}

variable "crucible_image_registry" {
  type        = string
  description = "Optional private registry prefix containing Zipline/Crucible images mirrored by zipline admin install. When set, Crucible gateway, history-server, and job runtime images default to this registry."
  default     = ""
  nullable    = false
}

variable "crucible_spark_image" {
  type        = string
  description = "Spark image the orchestration Hub passes to CrucibleSubmitter when deploy_crucible is true."
  default     = null
  nullable    = true
}

variable "crucible_flink_image" {
  type        = string
  description = "Flink image the orchestration Hub passes to CrucibleSubmitter when deploy_crucible is true."
  default     = null
  nullable    = true
}

variable "crucible_jar_name" {
  type        = string
  description = "Default Chronon jar name used by CrucibleSubmitter for AWS jobs."
  default     = "cloud_aws_lib_deploy.jar"
}

variable "crucible_jar_uri_override" {
  type        = string
  description = "Optional jar URI override passed to CrucibleSubmitter. Leave empty to use each workflow's submitted jar URI."
  default     = ""
}

variable "crucible_spot_executors" {
  type        = bool
  description = "Whether CrucibleSubmitter should request spot executors by default."
  default     = false
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
