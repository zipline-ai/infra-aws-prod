// Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
  backend "s3" {
    bucket = var.terraform_state_bucket
    key    = var.terraform_state_file
    region = var.terraform_state_region
  }
}

provider "aws" {
  region  = var.region
}

# Kubernetes provider - configured after EKS cluster is created
provider "kubernetes" {
  host                   = module.base_setup.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.base_setup.eks_cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.base_setup.eks_cluster_name, "--region", var.region]
  }
}

# Helm provider - uses same auth as kubernetes
provider "helm" {
  kubernetes {
    host                   = module.base_setup.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.base_setup.eks_cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.base_setup.eks_cluster_name, "--region", var.region]
    }
  }
}

# Kubectl provider - for applying CRDs
provider "kubectl" {
  host                   = module.base_setup.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.base_setup.eks_cluster_ca_certificate)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.base_setup.eks_cluster_name, "--region", var.region]
  }
}

module "base_setup" {
  source = "../base-aws"

  customer_name          = var.customer_name
  region                 = var.region
  artifact_prefix        = var.artifact_prefix
  zipline_version        = var.zipline_version
  dockerhub_token        = var.dockerhub_token
  personnel_arns         = var.personnel_arns

  # EKS Configuration
  eks_version = var.eks_version

  # Custom domains for HTTPS
  ui_domain      = var.ui_domain
  hub_domain       = var.hub_domain
  hub_external_url = var.hub_external_url
  fetcher_domain = var.fetcher_domain
  eval_domain    = var.eval_domain

  # Glue Schema Registry (optional)
  glue_schema_registry_name = var.glue_schema_registry_name

  # Databricks Unity Catalog integration (optional)
  databricks_client_id     = var.databricks_client_id
  databricks_client_secret = var.databricks_client_secret

  msk_cluster_arn = var.msk_cluster_arn

  # DynamoDB Configuration
  dynamodb_table_prefix    = var.dynamodb_table_prefix
  dynamodb_read_capacity   = var.dynamodb_read_capacity
  dynamodb_write_capacity  = var.dynamodb_write_capacity
}
