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
      customer_name   = var.customer_name
      aws_region      = var.region
      artifact_prefix = "s3://${var.warehouse_bucket}"
      version         = var.zipline_version

      db_host     = aws_db_instance.orchestration.endpoint
      db_name     = aws_db_instance.orchestration.db_name
      secrets_arn = aws_secretsmanager_secret.db_credentials.arn

      irsa_role_arn        = aws_iam_role.secrets_csi.arn
      image_pull_secret    = kubernetes_secret_v1.docker_hub_creds.metadata[0].name

      hub_domain = var.hub_domain
      ui_domain  = var.ui_domain
    })
  ]

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.default,
    helm_release.secrets_store_csi_aws,
    helm_release.aws_load_balancer_controller,
    aws_db_instance.orchestration,
    aws_secretsmanager_secret_version.db_credentials,
  ]
}
