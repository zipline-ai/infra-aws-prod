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
      ui_domain           = var.ui_domain
      dynamodb_table_name = var.dynamodb_table_name
      eks_cluster_name    = aws_eks_cluster.main.name

      # ACM certificate ARNs for HTTPS (empty string if no domain configured)
      ui_cert_arn  = var.ui_domain != "" ? aws_acm_certificate.ui_cert[0].arn : ""
      hub_cert_arn = var.hub_domain != "" ? aws_acm_certificate.hub_cert[0].arn : ""
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
  ]
}
