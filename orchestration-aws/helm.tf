# Helm releases for Zipline Orchestration

# Install Secrets Store CSI Driver
resource "helm_release" "secrets_store_csi" {
  name       = "secrets-store-csi-driver"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = "kube-system"
  version    = "1.4.1"

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }

  depends_on = [aws_eks_node_group.default]
}

# Install AWS Secrets Store CSI Driver Provider
resource "helm_release" "secrets_store_csi_aws" {
  name       = "secrets-store-csi-driver-provider-aws"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  namespace  = "kube-system"
  version    = "0.3.6"

  depends_on = [helm_release.secrets_store_csi]
}

# Install cert-manager (required by ADOT Operator)
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  version    = "v1.13.3"

  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [aws_eks_node_group.default]
}

# Install OpenTelemetry Operator
resource "helm_release" "opentelemetry_operator" {
  name       = "opentelemetry-operator"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-operator"
  namespace  = "opentelemetry-operator-system"
  version    = "0.47.0"

  create_namespace = true

  depends_on = [
    helm_release.cert_manager,
    aws_eks_node_group.default,
  ]
}

# Install Flink Kubernetes Operator
resource "helm_release" "flink_operator" {
  name       = "flink-kubernetes-operator"
  repository = "https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.14.0/"
  chart      = "flink-kubernetes-operator"
  namespace  = "flink-operator"
  version    = "1.14.0"

  create_namespace = true

  set {
    name  = "webhook.create"
    value = "false"
  }

  depends_on = [
    aws_eks_node_group.default,
  ]
}

# Service account for ADOT Collector with IRSA annotation
resource "kubernetes_service_account_v1" "adot_collector" {
  metadata {
    name      = "adot-collector"
    namespace = "opentelemetry-operator-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.adot_collector.arn
    }
  }

  depends_on = [helm_release.opentelemetry_operator]
}

# ADOT Collector configuration as OpenTelemetryCollector CRD
# Using kubectl provider to handle CRD that may not exist during plan
resource "kubectl_manifest" "adot_collector" {
  yaml_body = yamlencode({
    apiVersion = "opentelemetry.io/v1alpha1"
    kind       = "OpenTelemetryCollector"
    metadata = {
      name      = "adot-prometheus"
      namespace = "opentelemetry-operator-system"
    }
    spec = {
      mode           = "deployment"
      serviceAccount = "adot-collector"
      config = yamlencode({
        receivers = {
          otlp = {
            protocols = {
              http = {
                endpoint = "0.0.0.0:4318"
              }
              grpc = {
                endpoint = "0.0.0.0:4317"
              }
            }
          }
        }
        processors = {
          batch = {}
          # Resource processor adds cluster-level attributes
          resource = {
            attributes = [
              {
                key    = "cluster_name"
                value  = aws_eks_cluster.main.name
                action = "insert"
              },
              {
                key    = "region"
                value  = data.aws_region.current.name
                action = "insert"
              },
              {
                key    = "namespace"
                value  = "zipline-system"
                action = "insert"
              }
            ]
          }
          # Attributes processor adds labels to metric datapoints
          # Use upsert to override any app-set labels
          attributes = {
            actions = [
              {
                key    = "cluster_name"
                value  = aws_eks_cluster.main.name
                action = "upsert"
              },
              {
                key    = "aws_region"
                value  = data.aws_region.current.name
                action = "upsert"
              },
              {
                key    = "env"
                value  = var.name_prefix
                action = "upsert"
              },
              {
                key    = "namespace"
                value  = "zipline-system"
                action = "upsert"
              }
            ]
          }
        }
        exporters = {
          prometheusremotewrite = {
            endpoint = "${aws_prometheus_workspace.main.prometheus_endpoint}api/v1/remote_write"
            auth = {
              authenticator = "sigv4auth"
            }
          }
        }
        extensions = {
          sigv4auth = {
            region = data.aws_region.current.name
          }
          health_check = {}
        }
        service = {
          extensions = ["sigv4auth", "health_check"]
          pipelines = {
            metrics = {
              receivers  = ["otlp"]
              processors = ["attributes", "batch", "resource"]
              exporters  = ["prometheusremotewrite"]
            }
          }
        }
      })
    }
  })

  depends_on = [
    helm_release.opentelemetry_operator,
    kubernetes_service_account_v1.adot_collector,
    aws_prometheus_workspace.main,
  ]
}

# Deploy Zipline Orchestration using Helm
resource "helm_release" "zipline_orchestration" {
  name             = "zipline-orchestration"
  chart            = "${path.module}/../charts/zipline-orchestration"
  namespace        = kubernetes_namespace_v1.zipline_system.metadata[0].name
  create_namespace = false

  # Don't wait for pods to be ready - allows terraform to complete
  # even if images aren't available yet
  wait    = false
  timeout = 600

  values = [
    templatefile("${path.module}/helm-values.yaml.tpl", {
      fetcher_replicas = var.fetcher_replicas
      customer_name   = var.name_prefix
      aws_region      = data.aws_region.current.name
      artifact_prefix = var.artifact_prefix
      version         = var.zipline_version

      # RDS instance + self-managed secret
      db_host     = aws_db_instance.zipline.endpoint
      db_name     = aws_db_instance.zipline.db_name
      secrets_arn = aws_secretsmanager_secret.db_credentials.arn

      irsa_role_arn     = aws_iam_role.orchestration_irsa.arn
      image_pull_secret = kubernetes_secret_v1.docker_hub_creds.metadata[0].name

      hub_domain          = var.hub_domain
      hub_external_url    = var.hub_external_url
      ui_domain           = var.ui_domain
      fetcher_domain      = var.fetcher_domain
      eval_domain         = var.eval_domain
      kv_table_prefix     = module.dynamodb_tables.table_prefix
      eks_cluster_name          = aws_eks_cluster.main.name
      flink_eks_service_account = kubernetes_service_account_v1.flink_job.metadata[0].name
      flink_eks_namespace       = kubernetes_namespace_v1.zipline_flink.metadata[0].name

      # EMR Serverless (execution role ARN derived by naming convention)
      emr_serverless_execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/zipline_${var.name_prefix}_emr_serverless_role"
      emr_log_uri                       = var.emr_log_uri != "" ? var.emr_log_uri : "s3://zipline-logs-${var.name_prefix}/emr/"
      emr_cloudwatch_log_group          = var.emr_cloudwatch_log_group

      # ACM certificate ARNs for HTTPS (empty string if no domain configured)
      ui_cert_arn      = var.ui_domain != "" ? aws_acm_certificate.ui_cert[0].arn : ""
      hub_cert_arn     = var.hub_domain != "" ? aws_acm_certificate.hub_cert[0].arn : ""
      fetcher_cert_arn = var.fetcher_domain != "" ? aws_acm_certificate.fetcher_cert[0].arn : ""
      eval_cert_arn    = var.eval_domain != "" ? aws_acm_certificate.eval_cert[0].arn : ""

      # Databricks service principal secret ARN (empty if not configured)
      databricks_sp_secret_arn = var.databricks_client_id != "" ? aws_secretsmanager_secret.databricks_sp[0].arn : ""

      # Prometheus configuration
      prometheus_query_endpoint = trimsuffix(aws_prometheus_workspace.main.prometheus_endpoint, "/")

      zipline_auth_enabled = var.zipline_auth_enabled
      zipline_auth_url     = var.ui_domain != "" ? "https://${var.ui_domain}" : "http://zipline-orchestration-ui.zipline-system.svc.cluster.local:3000"
      zipline_auth_secret  = random_password.zipline_auth.result
      zipline_auth_jwksUrl = "https://${var.ui_domain != "" ? var.ui_domain : "http://zipline-orchestration-ui.zipline-system.svc.cluster.local:3000"}/api/auth/jwks"
      google_oauth_client_id = var.google_oauth_client_id
      google_oauth_client_secret = var.google_oauth_client_secret
      github_oauth_client_id = var.github_oauth_client_id
      github_oauth_client_secret = var.github_oauth_client_secret
      microsoft_entra_tenant_id = var.microsoft_entra_tenant_id
      microsoft_entra_oauth_client_id = var.microsoft_entra_oauth_client_id
      microsoft_entra_oauth_client_secret = var.microsoft_entra_oauth_client_secret
      sso_provider_id = var.sso_provider_id
      sso_domain = var.sso_domain
      sso_issuer = var.sso_issuer
      sso_client_id = var.sso_client_id
      sso_client_secret = var.sso_client_secret
      idp_role_mapping = var.idp_role_mapping
      idp_group_claim = var.idp_group_claim

    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.default,
    helm_release.secrets_store_csi_aws,
    helm_release.aws_load_balancer_controller,
    aws_db_instance.zipline,
    aws_acm_certificate.ui_cert,
    aws_acm_certificate.hub_cert,
    aws_acm_certificate.fetcher_cert,
    aws_acm_certificate.eval_cert,
  ]
}

resource "random_password" "zipline_auth" {
  length           = 32
  special          = true
  override_special = "!@#$%^&*"
  min_special      = 1
  # The resulting password will be stored in the state file.
}

resource "aws_secretsmanager_secret" "zipline_auth" {
  name = "zipline-auth-secret"
}

resource "aws_secretsmanager_secret_version" "zipline_auth" {
  secret_id = aws_secretsmanager_secret.zipline_auth.id
  secret_string = jsonencode({
    auth-secret = random_password.zipline_auth.result
  })
}