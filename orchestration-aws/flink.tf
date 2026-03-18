# Flink on EKS Configuration
# This file contains Kubernetes resources for Flink jobs with IRSA support

# Explicitly manage the FlinkDeployment CRD via kubectl_manifest so that
# terraform apply recreates it if it is deleted out-of-band.
# Helm skips CRD reinstallation by design, so this is the only reliable way
# to ensure the CRD stays in sync with Terraform state.
resource "kubectl_manifest" "flinkdeployments_crd" {
  yaml_body = file("${path.module}/crds/flinkdeployments.flink.apache.org-v1.yml")

  depends_on = [aws_eks_node_group.default]
}

# Service Account for Flink jobs with IRSA annotation
resource "kubernetes_service_account_v1" "flink_job" {
  metadata {
    name      = "zipline-flink-sa"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.flink_job_execution.arn
    }
  }

  depends_on = [
    helm_release.flink_operator,
    kubectl_manifest.flinkdeployments_crd,
    aws_iam_role.flink_job_execution,
  ]
}

# RBAC Role for Flink jobs
resource "kubernetes_role_v1" "flink_role" {
  metadata {
    name      = "flink-role"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  # Pod management permissions
  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch"]
  }

  # Pod logs access
  rule {
    api_groups = [""]
    resources  = ["pods/log"]
    verbs      = ["get", "list"]
  }

  # ConfigMap management for Flink configuration
  rule {
    api_groups = [""]
    resources  = ["configmaps"]
    verbs      = ["create", "delete", "get", "list", "patch", "update", "watch"]
  }

  # Service management for Flink UI and communication
  rule {
    api_groups = [""]
    resources  = ["services"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch", "update"]
  }

  # Deployment read access
  rule {
    api_groups = ["apps"]
    resources  = ["deployments"]
    verbs      = ["get", "list", "watch"]
  }

  # Ingress management for Flink UI routing via nginx-hub
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "delete", "patch", "update"]
  }

  depends_on = [helm_release.flink_operator]
}

# Role granting orchestration-sa permission to manage FlinkDeployments in zipline-flink.
# orchestration-sa (zipline-system) is the in-cluster identity used by EksFlinkSubmitter
# to create/get/delete FlinkDeployment CRs via the Kubernetes API.
resource "kubernetes_role_v1" "orchestration_flink_role" {
  metadata {
    name      = "orchestration-flink-role"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  rule {
    api_groups = ["flink.apache.org"]
    resources  = ["flinkdeployments"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  # Ingress management so EksFlinkSubmitter can create/delete per-deployment ingress rules
  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "create", "update", "patch", "delete"]
  }

  depends_on = [
    kubectl_manifest.flinkdeployments_crd,
    helm_release.flink_operator,
  ]
}

resource "kubernetes_role_binding_v1" "orchestration_flink_role_binding" {
  metadata {
    name      = "orchestration-flink-role-binding"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.orchestration_flink_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "orchestration-sa"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  depends_on = [kubernetes_role_v1.orchestration_flink_role]
}

# RBAC RoleBinding for Flink service account
resource "kubernetes_role_binding_v1" "flink_role_binding" {
  metadata {
    name      = "flink-role-binding"
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role_v1.flink_role.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.flink_job.metadata[0].name
    namespace = kubernetes_namespace_v1.zipline_flink.metadata[0].name
  }

  depends_on = [
    kubernetes_role_v1.flink_role,
    kubernetes_service_account_v1.flink_job,
  ]
}
