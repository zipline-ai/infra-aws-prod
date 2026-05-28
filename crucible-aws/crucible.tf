locals {
  default_crucible_chart_values = yamlencode({
    cloudProvider = "aws"

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

    namespaceOnboarding = {
      clusterName   = module.cluster.cluster_name
      eksOIDCIssuer = module.cluster.cluster_oidc_issuer
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
      publicUrl = "https://${var.public_host}/api/v1/history"
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
  ]
}
