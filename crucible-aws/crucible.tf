###############################################################################
# Crucible gateway + operators.
#
# The chart itself is tracked in this repo. Environment-specific values are
# pulled from S3 by pull_canary_config.sh before plan/apply.
###############################################################################

locals {
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

  values = local.crucible_chart_values

  depends_on = [
    helm_release.ingress_nginx,
    aws_eks_node_group.control,
    aws_eks_node_group.default,
    aws_iam_role_policy.gateway_s3,
    aws_iam_role_policy.gateway_iam,
    aws_iam_role_policy.spark_s3,
    aws_s3_bucket.crucible,
  ]
}
