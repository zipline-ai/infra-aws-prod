variable "region" {
}

variable "customer_name" {
}

variable "artifact_prefix" {
}

variable "dockerhub_token" {
}

variable "emr_subnetwork" {
  default = ""
}

variable "emr_tags" {
  default = {}
}

variable "emr_bootstrap_actions" {
  default = {}
}

variable "control_plane_account_id" {
  default = "345594603419"
}