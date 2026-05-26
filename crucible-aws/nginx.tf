###############################################################################
# nginx-ingress controller — one helm release. NLB created by the controller's
# Service (annotated to terminate TLS using the ACM cert from acm.tf).
#
# This is the cloud-specific seam. Migrating to GCP/Azure swaps these three
# `aws-load-balancer-*` annotations for the equivalent cloud-native annotations
# and points at that cloud's cert (Key Vault on Azure, managed cert on GCP).
# Every Ingress resource above this remains identical.
###############################################################################

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  namespace        = "crucible-system"
  create_namespace = true

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.3"

  wait    = true
  timeout = 600

  depends_on = [aws_eks_node_group.control]

  values = [yamlencode({
    controller = {
      ingressClassResource = {
        name = "nginx"
      }
      ingressClass = "nginx"

      nodeSelector = {
        "workload-plane" = "control"
      }

      tolerations = [
        {
          key      = "dedicated"
          operator = "Equal"
          value    = "crucible-system"
          effect   = "NoSchedule"
        }
      ]

      service = {
        type = "LoadBalancer"
        # NLB terminates TLS on port 443 and forwards plaintext to nginx's
        # HTTP port. Mapping `https -> http` is the canonical "TLS terminated
        # at LB" config for ingress-nginx.
        targetPorts = {
          http  = "http"
          https = "http"
        }
        annotations = merge({
          # Legacy in-tree NLB (works without AWS Load Balancer Controller).
          "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"

          # ACM cert + TLS termination at the NLB.
          "service.beta.kubernetes.io/aws-load-balancer-ssl-cert"                = aws_acm_certificate_validation.crucible_aws.certificate_arn
          "service.beta.kubernetes.io/aws-load-balancer-ssl-ports"               = "443"
          "service.beta.kubernetes.io/aws-load-balancer-backend-protocol"        = "tcp"
          "service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout" = "60"
          }, length(local.ingress_nlb_subnet_ids) > 0 ? {
          "service.beta.kubernetes.io/aws-load-balancer-subnets" = join(",", local.ingress_nlb_subnet_ids)
        } : {})
      }

      config = {
        # nginx is downstream of an L4 NLB that's terminating TLS;
        # honor the X-Forwarded-* the LB emits.
        "use-forwarded-headers" = "true"
      }
    }
  })]
}
