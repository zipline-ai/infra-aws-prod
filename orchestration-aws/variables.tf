variable "region" {
  description = "AWS region for deployment"
  type        = string
}

variable "customer_name" {
  description = "Unique identifier for the customer deployment"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where resources will be deployed"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for EKS and RDS"
  type        = list(string)
}

variable "warehouse_bucket" {
  description = "Name of the S3 warehouse bucket"
  type        = string
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

# EKS Configuration
variable "eks_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.29"
}

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

variable "eks_disk_size" {
  description = "Disk size in GB for EKS nodes"
  type        = number
  default     = 100
}

# RDS Configuration
variable "rds_instance_class" {
  description = "Instance class for RDS PostgreSQL"
  type        = string
  default     = "db.t3.medium"
}

variable "rds_allocated_storage" {
  description = "Allocated storage in GB for RDS"
  type        = number
  default     = 32
}

variable "rds_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16"
}

variable "rds_multi_az" {
  description = "Enable Multi-AZ for RDS"
  type        = bool
  default     = false
}

variable "rds_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

# Domain Configuration
variable "hub_domain" {
  description = "Custom domain for orchestration hub (optional)"
  type        = string
  default     = ""
}

variable "ui_domain" {
  description = "Custom domain for orchestration UI (optional)"
  type        = string
  default     = ""
}
