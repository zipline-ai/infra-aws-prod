terraform {
  required_version = ">= 1.0"

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
}

provider "aws" {
  region = "us-west-2"

  default_tags {
    tags = {
      Project     = "Zipline"
      Customer    = var.customer_name
      ManagedBy   = "Terraform"
      Environment = "nightly-test"
    }
  }
}

provider "kubernetes" {
  host                   = module.base_setup.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.base_setup.eks_cluster_ca_certificate)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.base_setup.eks_cluster_name, "--region", "us-west-2"]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.base_setup.eks_cluster_endpoint
    cluster_ca_certificate = base64decode(module.base_setup.eks_cluster_ca_certificate)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.base_setup.eks_cluster_name, "--region", "us-west-2"]
    }
  }
}

provider "kubectl" {
  host                   = module.base_setup.eks_cluster_endpoint
  cluster_ca_certificate = base64decode(module.base_setup.eks_cluster_ca_certificate)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.base_setup.eks_cluster_name, "--region", "us-west-2"]
  }
}
