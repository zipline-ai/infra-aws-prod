locals {
  artifact_bucket_name = split("/", trimprefix(var.artifact_prefix, "s3://"))[0]

  crucible_cluster_name = var.crucible_cluster_name != "" ? var.crucible_cluster_name : "${var.customer_name}-crucible-eks"
  crucible_bucket_name  = var.crucible_bucket_name != "" ? var.crucible_bucket_name : "zipline-crucible-${lower(var.customer_name)}"
  crucible_subnet_ids   = [module.base_setup.primary_subnet_id, module.base_setup.secondary_subnet_id]

  crucible_job_namespace = trimspace(var.crucible_job_namespace)
  crucible_gateway_url   = var.deploy_crucible && trimspace(var.crucible_public_host) != "" ? "https://${trimspace(var.crucible_public_host)}" : ""

  crucible_ingress_nlb_subnet_ids = length(var.crucible_ingress_nlb_subnet_ids) > 0 ? var.crucible_ingress_nlb_subnet_ids : local.crucible_subnet_ids
  crucible_chronon_artifact_buckets = distinct(compact(concat(
    [local.artifact_bucket_name],
    var.additional_data_buckets,
  )))
}

resource "terraform_data" "crucible_config_validation" {
  count = var.deploy_crucible ? 1 : 0

  input = var.crucible_public_host

  lifecycle {
    precondition {
      condition     = trimspace(var.crucible_public_host) != ""
      error_message = "crucible_public_host must be set when deploy_crucible is true."
    }
  }
}

module "crucible_cluster" {
  count  = var.deploy_crucible ? 1 : 0
  source = "../crucible-aws/modules/cluster"

  region       = var.region
  cluster_name = local.crucible_cluster_name

  shared_vpc_id          = module.base_setup.vpc_id
  shared_subnet_ids      = local.crucible_subnet_ids
  ingress_nlb_subnet_ids = local.crucible_ingress_nlb_subnet_ids

  personnel_arns          = var.personnel_arns
  crucible_bucket_name    = local.crucible_bucket_name
  public_host             = trimspace(var.crucible_public_host)
  job_namespace           = local.crucible_job_namespace
  eks_public_access_cidrs = var.crucible_eks_public_access_cidrs

  chronon_artifact_buckets  = local.crucible_chronon_artifact_buckets
  chronon_warehouse_buckets = [module.base_setup.warehouse_bucket_name]

  depends_on = [terraform_data.crucible_config_validation]
}

provider "kubernetes" {
  alias = "crucible"

  host                   = try(module.crucible_cluster[0].cluster_endpoint, module.base_setup.eks_cluster_endpoint)
  cluster_ca_certificate = base64decode(try(module.crucible_cluster[0].cluster_ca_certificate, module.base_setup.eks_cluster_ca_certificate))

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", try(module.crucible_cluster[0].cluster_name, module.base_setup.eks_cluster_name), "--region", var.region]
  }
}

provider "helm" {
  alias = "crucible"

  kubernetes {
    host                   = try(module.crucible_cluster[0].cluster_endpoint, module.base_setup.eks_cluster_endpoint)
    cluster_ca_certificate = base64decode(try(module.crucible_cluster[0].cluster_ca_certificate, module.base_setup.eks_cluster_ca_certificate))

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", try(module.crucible_cluster[0].cluster_name, module.base_setup.eks_cluster_name), "--region", var.region]
    }
  }
}

module "crucible_ingress_nginx" {
  count  = var.deploy_crucible ? 1 : 0
  source = "../crucible-aws/modules/ingress-nginx"

  providers = {
    helm       = helm.crucible
    kubernetes = kubernetes.crucible
  }

  acm_certificate_arn    = module.crucible_cluster[0].acm_certificate_arn
  ingress_nlb_subnet_ids = module.crucible_cluster[0].ingress_nlb_subnet_ids

  depends_on = [module.crucible_cluster]
}

resource "helm_release" "crucible" {
  count = var.deploy_crucible ? 1 : 0

  provider = helm.crucible

  name             = "crucible"
  namespace        = "crucible-system"
  create_namespace = true

  repository = var.crucible_chart_repository
  chart      = var.crucible_chart_name
  version    = var.crucible_chart_version

  wait    = true
  timeout = 600

  values = [
    yamlencode({
      cloudProvider = "aws"

      objectStore = {
        bucket = "s3://${module.crucible_cluster[0].crucible_bucket_name}"
        region = var.region
      }

      serviceAccount = {
        create = true
        annotations = {
          "eks.amazonaws.com/role-arn" = module.crucible_cluster[0].gateway_role_arn
        }
      }

      namespaceOnboarding = {
        clusterName   = module.crucible_cluster[0].cluster_name
        eksOIDCIssuer = module.crucible_cluster[0].cluster_oidc_issuer
      }

      gateway = {
        defaultJobNamespace = local.crucible_job_namespace
      }

      sparkDefaults = {
        serviceAccountAnnotations = {
          "eks.amazonaws.com/role-arn" = module.crucible_cluster[0].spark_role_arn
        }
      }

      ingress = {
        enabled   = true
        className = "nginx"
        host      = trimspace(var.crucible_public_host)
      }

      historyServer = {
        enabled   = true
        publicUrl = "https://${trimspace(var.crucible_public_host)}/api/v1/history"
        ingress = {
          enabled   = true
          host      = trimspace(var.crucible_public_host)
          className = "nginx"
        }
      }
    })
  ]

  depends_on = [
    module.crucible_cluster,
    module.crucible_ingress_nginx,
  ]
}

output "crucible_cluster_name" {
  description = "EKS cluster name for Crucible, or null when Crucible is disabled."
  value       = try(module.crucible_cluster[0].cluster_name, null)
}

output "crucible_bucket_name" {
  description = "S3 bucket name for Crucible event logs, jars, and checkpoints, or null when disabled."
  value       = try(module.crucible_cluster[0].crucible_bucket_name, null)
}

output "crucible_gateway_role_arn" {
  description = "IRSA role ARN for the Crucible gateway service account, or null when disabled."
  value       = try(module.crucible_cluster[0].gateway_role_arn, null)
}

output "crucible_spark_role_arn" {
  description = "IRSA role ARN for Crucible Spark and Flink service accounts, or null when disabled."
  value       = try(module.crucible_cluster[0].spark_role_arn, null)
}

output "crucible_acm_validation_records" {
  description = "DNS validation records for the Crucible ACM certificate, or null when disabled."
  value       = try(module.crucible_cluster[0].acm_validation_records, null)
}

output "crucible_ingress_nlb_hostname" {
  description = "NLB hostname for Crucible ingress, or null when disabled."
  value       = try(module.crucible_ingress_nginx[0].ingress_nlb_hostname, null)
}
