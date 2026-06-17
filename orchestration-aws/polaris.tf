locals {
  polaris_realm = trimspace(var.polaris_realm) != "" ? trimspace(var.polaris_realm) : var.name_prefix
}

resource "random_password" "polaris_root_client_secret" {
  length  = 48
  special = false
}

resource "kubernetes_secret_v1" "polaris_bootstrap_credentials" {
  metadata {
    name      = "polaris-bootstrap-credentials"
    namespace = kubernetes_namespace_v1.zipline_system.metadata[0].name
  }

  type = "Opaque"

  data = {
    credentials = "${local.polaris_realm},root,${random_password.polaris_root_client_secret.result}"
  }

  lifecycle {
    ignore_changes = [data]
  }
}
