output "ingress_nlb_hostname" {
  description = "NLB hostname provisioned by the nginx-ingress controller. CNAME the Crucible public host to this in your DNS provider."
  value       = try(data.kubernetes_service.ingress_nginx.status[0].load_balancer[0].ingress[0].hostname, "(NLB hostname will appear after first apply completes)")
}

# Reads the nginx-ingress Service after helm release creates it, so the output
# above can surface the NLB hostname terraform-side.
data "kubernetes_service" "ingress_nginx" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = helm_release.ingress_nginx.namespace
  }
  depends_on = [helm_release.ingress_nginx]
}
