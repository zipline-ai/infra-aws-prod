variable "dockerhub_token" {
    type        = string
    description = "Docker Hub access token for ECR Pull Through Cache"
    default = ""
}

variable "zipline_version" {
    type        = string
    description = "The version of Zipline to deploy. This should correspond to a valid Docker image tag in the Zipline repository."
    default     = "latest"
}

variable "name_prefix" {}

variable "artifact_prefix" {
    type        = string
    description = "The s3 prefix where Zipline artifacts are stored."
}

variable "security_group_id" {
    type        = string
    description = "The security group ID to attach to resources."
}

variable "main_subnet_id" {
    type        = string
    description = "The subnet ID to deploy resources into."
}

variable "secondary_subnet_id" {
    type        = string
    description = "The subnet ID to deploy resources into."
}