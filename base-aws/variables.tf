variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "customer_name" {
  description = "Customer name used for resource naming"
  type        = string
}

variable "emr_subnetwork" {
  description = "Optional subnet ID for EMR cluster. If not set, uses the main subnet."
  type        = string
  default     = ""
}

variable "emr_tags" {
  description = "Additional tags to apply to EMR resources"
  type        = map(string)
  default     = {}
}

variable "emr_bootstrap_actions" {
  description = "Map of bootstrap action names to S3 script paths"
  type        = map(string)
  default     = {}
}

# Access control (following GCP pattern)
variable "personnel_iam_group" {
  description = "IAM group name for admin personnel (e.g., 'zipline-admins')"
  type        = string
  default     = ""
}

variable "users_iam_group" {
  description = "IAM group name for end users (e.g., 'zipline-users')"
  type        = string
  default     = ""
}

# EMR instance configuration
variable "emr_master_instance_type" {
  description = "Instance type for EMR master node"
  type        = string
  default     = "m5.xlarge"
}

variable "emr_core_instance_type" {
  description = "Instance type for EMR core nodes"
  type        = string
  default     = "m5.xlarge"
}

variable "emr_master_ebs_size" {
  description = "EBS volume size in GB for master node"
  type        = number
  default     = 32
}

variable "emr_core_ebs_size" {
  description = "EBS volume size in GB for core nodes"
  type        = number
  default     = 32
}

variable "emr_autoscaling_min" {
  description = "Minimum number of EMR instances for autoscaling"
  type        = number
  default     = 1
}

variable "emr_autoscaling_max" {
  description = "Maximum number of EMR instances for autoscaling"
  type        = number
  default     = 10
}

variable "emr_release_label" {
  description = "EMR release label version"
  type        = string
  default     = "emr-7.12.0"
}

# DynamoDB scaling
variable "dynamo_read_capacity" {
  description = "DynamoDB read capacity units"
  type        = number
  default     = 10
}

variable "dynamo_write_capacity" {
  description = "DynamoDB write capacity units"
  type        = number
  default     = 10
}

# Network customization
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "subnet_cidrs" {
  description = "CIDR blocks for subnets (must be within vpc_cidr)"
  type        = list(string)
  default     = ["172.31.0.0/20", "172.31.16.0/20"]
}
