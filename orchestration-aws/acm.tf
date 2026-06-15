# ACM Certificates for HTTPS
# These certificates are FREE when used with AWS services (NLB, ALB, CloudFront)
# They use TLS 1.2/1.3 (modern, secure encryption)

locals {
  zipline_custom_domain_host = trimsuffix(trimprefix(trimprefix(trimspace(var.zipline_custom_domain), "https://"), "http://"), "/")
  use_zipline_custom_domain  = local.zipline_custom_domain_host != ""

  ui_domain      = local.use_zipline_custom_domain ? local.zipline_custom_domain_host : var.ui_domain
  hub_domain     = local.use_zipline_custom_domain ? local.zipline_custom_domain_host : var.hub_domain
  fetcher_domain = local.use_zipline_custom_domain ? local.zipline_custom_domain_host : var.fetcher_domain
  eval_domain    = local.use_zipline_custom_domain ? local.zipline_custom_domain_host : var.eval_domain

  ui_path      = "/"
  hub_path     = local.use_zipline_custom_domain ? "/services/hub" : "/"
  fetcher_path = local.use_zipline_custom_domain ? "/services/fetcher" : "/"
  eval_path    = local.use_zipline_custom_domain ? "/services/eval" : "/"

  ui_ingress_class      = "nginx-ui"
  hub_ingress_class     = local.use_zipline_custom_domain ? "nginx-ui" : "nginx-hub"
  fetcher_ingress_class = local.use_zipline_custom_domain ? "nginx-ui" : "nginx-fetcher"
  eval_ingress_class    = local.use_zipline_custom_domain ? "nginx-ui" : "nginx-eval"

  provided_zipline_custom_domain_cert_arn = var.zipline_custom_domain_cert_arn != "" ? var.zipline_custom_domain_cert_arn : var.ui_cert_arn
  zipline_custom_domain_cert_arn          = local.use_zipline_custom_domain ? (local.provided_zipline_custom_domain_cert_arn != "" ? local.provided_zipline_custom_domain_cert_arn : aws_acm_certificate.zipline_custom_domain_cert[0].arn) : ""

  ui_cert_arn      = local.use_zipline_custom_domain ? local.zipline_custom_domain_cert_arn : (local.ui_domain != "" ? (var.ui_cert_arn != "" ? var.ui_cert_arn : aws_acm_certificate.ui_cert[0].arn) : "")
  hub_cert_arn     = local.use_zipline_custom_domain ? local.zipline_custom_domain_cert_arn : (local.hub_domain != "" ? (var.hub_cert_arn != "" ? var.hub_cert_arn : aws_acm_certificate.hub_cert[0].arn) : "")
  fetcher_cert_arn = local.use_zipline_custom_domain ? local.zipline_custom_domain_cert_arn : (local.fetcher_domain != "" ? (var.fetcher_cert_arn != "" ? var.fetcher_cert_arn : aws_acm_certificate.fetcher_cert[0].arn) : "")
  eval_cert_arn    = local.use_zipline_custom_domain ? local.zipline_custom_domain_cert_arn : (local.eval_domain != "" ? (var.eval_cert_arn != "" ? var.eval_cert_arn : aws_acm_certificate.eval_cert[0].arn) : "")

  zipline_auth_url      = local.ui_domain != "" ? "https://${local.ui_domain}" : "http://zipline-orchestration-ui.zipline-system.svc.cluster.local:3000"
  zipline_auth_jwks_url = "${local.zipline_auth_url}/api/auth/jwks"
}

resource "aws_acm_certificate" "zipline_custom_domain_cert" {
  count = local.use_zipline_custom_domain && local.provided_zipline_custom_domain_cert_arn == "" ? 1 : 0

  domain_name       = local.zipline_custom_domain_host
  validation_method = "DNS"

  tags = {
    Name = "${var.name_prefix}-zipline-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate for UI domain (e.g., canary-aws.zipline.ai)
resource "aws_acm_certificate" "ui_cert" {
  count = !local.use_zipline_custom_domain && local.ui_domain != "" && var.ui_cert_arn == "" ? 1 : 0

  domain_name       = local.ui_domain
  validation_method = "DNS" # Prove ownership by adding a CNAME record

  tags = {
    Name = "${var.name_prefix}-ui-cert"
  }

  # Create new cert before destroying old one (for renewals/changes)
  lifecycle {
    create_before_destroy = true
  }
}

# Certificate for Hub domain (e.g., canary-orch-aws.zipline.ai)
resource "aws_acm_certificate" "hub_cert" {
  count = !local.use_zipline_custom_domain && local.hub_domain != "" && var.hub_cert_arn == "" ? 1 : 0

  domain_name       = local.hub_domain
  validation_method = "DNS"

  tags = {
    Name = "${var.name_prefix}-hub-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate for Fetcher domain (e.g., canary-fetcher-aws.zipline.ai)
resource "aws_acm_certificate" "fetcher_cert" {
  count = !local.use_zipline_custom_domain && local.fetcher_domain != "" && var.fetcher_cert_arn == "" ? 1 : 0

  domain_name       = local.fetcher_domain
  validation_method = "DNS"

  tags = {
    Name = "${var.name_prefix}-fetcher-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Certificate for Eval domain (e.g., canary-eval-aws.zipline.ai)
resource "aws_acm_certificate" "eval_cert" {
  count = !local.use_zipline_custom_domain && local.eval_domain != "" && var.eval_cert_arn == "" ? 1 : 0

  domain_name       = local.eval_domain
  validation_method = "DNS"

  tags = {
    Name = "${var.name_prefix}-eval-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Output the DNS validation records needed
# You'll need to add these CNAME records to your DNS provider to validate the certificates
output "ui_cert_validation_records" {
  description = "DNS records to add for UI certificate validation"
  value = local.ui_domain != "" && (local.use_zipline_custom_domain ? local.provided_zipline_custom_domain_cert_arn == "" : var.ui_cert_arn == "") ? [
    for dvo in(local.use_zipline_custom_domain ? aws_acm_certificate.zipline_custom_domain_cert[0].domain_validation_options : aws_acm_certificate.ui_cert[0].domain_validation_options) : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

output "hub_cert_validation_records" {
  description = "DNS records to add for Hub certificate validation"
  value = !local.use_zipline_custom_domain && local.hub_domain != "" && var.hub_cert_arn == "" ? [
    for dvo in aws_acm_certificate.hub_cert[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

output "eval_cert_validation_records" {
  description = "DNS records to add for Eval certificate validation"
  value = !local.use_zipline_custom_domain && local.eval_domain != "" && var.eval_cert_arn == "" ? [
    for dvo in aws_acm_certificate.eval_cert[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

# Output the certificate ARNs (needed by the load balancer)
output "ui_cert_arn" {
  description = "ARN of the UI certificate"
  value       = local.ui_cert_arn
}

output "hub_cert_arn" {
  description = "ARN of the Hub certificate"
  value       = local.hub_cert_arn
}

output "fetcher_cert_validation_records" {
  description = "DNS records to add for Fetcher certificate validation"
  value = !local.use_zipline_custom_domain && local.fetcher_domain != "" && var.fetcher_cert_arn == "" ? [
    for dvo in aws_acm_certificate.fetcher_cert[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

output "fetcher_cert_arn" {
  description = "ARN of the Fetcher certificate"
  value       = local.fetcher_cert_arn
}

output "eval_cert_arn" {
  description = "ARN of the Eval certificate"
  value       = local.eval_cert_arn
}
