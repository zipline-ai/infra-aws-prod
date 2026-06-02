terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.16"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.33"
    }
  }

  # Reuse the same state bucket as zipline-aws/ but under a separate key so
  # crucible can plan/apply independently of the canary stack.
  backend "s3" {
    bucket = "zipline-ai-opentofu-state-bucket"
    key    = "opentofu-crucible-state"
    region = "us-west-1"
  }
}

provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = aws_eks_cluster.crucible.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.crucible.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.crucible.name, "--region", var.region]
  }
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.crucible.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.crucible.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.crucible.name, "--region", var.region]
    }
  }
}
