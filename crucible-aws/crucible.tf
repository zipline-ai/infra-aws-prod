locals {
  default_crucible_chart_values = yamlencode({
    cloudProvider = "aws"

    image = {
      repository = var.crucible_gateway_image_repository
      tag        = var.crucible_gateway_image_tag
      pullPolicy = var.crucible_gateway_image_pull_policy
    }

    objectStore = {
      bucket = "s3://${module.cluster.crucible_bucket_name}"
      region = var.region
    }

    serviceAccount = {
      create = true
      annotations = {
        "eks.amazonaws.com/role-arn" = module.cluster.gateway_role_arn
      }
    }

    namespaces = {
      managed = [var.job_namespace]
    }

    gateway = {
      namespace           = "crucible-system"
      defaultJobNamespace = var.job_namespace
    }

    sparkDefaults = {
      serviceAccountAnnotations = {
        "eks.amazonaws.com/role-arn" = module.cluster.spark_role_arn
      }
    }

    ingress = {
      enabled   = true
      className = "nginx"
      host      = var.public_host
    }

    historyServer = {
      enabled   = true
      publicUrl = "https://${var.public_host}/spark-history"
      ingress = {
        enabled   = true
        host      = var.public_host
        className = "nginx"
      }
    }
  })

  crucible_chart_values = [
    for path in var.crucible_chart_values_files : file("${path.module}/${path}")
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  version          = "v1.13.3"
  create_namespace = true

  wait    = true
  timeout = 600

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [module.cluster]
}

resource "helm_release" "crucible" {
  name             = "crucible"
  namespace        = "crucible-system"
  create_namespace = true

  chart = "${path.module}/charts/crucible"

  wait    = true
  timeout = 600

  values = concat([local.default_crucible_chart_values], local.crucible_chart_values)

  depends_on = [
    module.cluster,
    module.ingress_nginx,
    helm_release.cert_manager,
  ]
}
