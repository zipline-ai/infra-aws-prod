variable "region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "customer_name" {
  description = "Unique identifier for your deployment (lowercase, alphanumeric, hyphens allowed)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.customer_name))
    error_message = "customer_name must be lowercase alphanumeric with hyphens only."
  }
}

variable "zipline_version" {
  description = "Version of Zipline to deploy"
  type        = string
  default     = "0.9.7"
}

variable "docker_hub_token" {
  description = "Docker Hub token for pulling Zipline images"
  type        = string
  sensitive   = true
}

# Base infrastructure configuration
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "personnel_iam_group" {
  description = "IAM group name for admin personnel (optional)"
  type        = string
  default     = ""
}

variable "users_iam_group" {
  description = "IAM group name for end users (optional)"
  type        = string
  default     = ""
}

# EMR configuration
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

variable "emr_autoscaling_min" {
  description = "Minimum number of EMR instances"
  type        = number
  default     = 1
}

variable "emr_autoscaling_max" {
  description = "Maximum number of EMR instances"
  type        = number
  default     = 10
}

# DynamoDB configuration
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

# EKS configuration
variable "eks_instance_type" {
  description = "Instance type for EKS node group"
  type        = string
  default     = "m5.2xlarge"
}

variable "eks_desired_size" {
  description = "Desired number of nodes in EKS node group"
  type        = number
  default     = 3
}

variable "eks_min_size" {
  description = "Minimum number of nodes in EKS node group"
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of nodes in EKS node group"
  type        = number
  default     = 5
}

# RDS configuration
variable "rds_instance_class" {
  description = "Instance class for RDS PostgreSQL"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

# Domain configuration (optional)
variable "hub_domain" {
  description = "Custom domain for orchestration hub"
  type        = string
  default     = ""
}

variable "ui_domain" {
  description = "Custom domain for orchestration UI"
  type        = string
  default     = ""
}
