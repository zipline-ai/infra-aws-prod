# ACM Certificates for HTTPS
# These certificates are FREE when used with AWS services (NLB, ALB, CloudFront)
# They use TLS 1.2/1.3 (modern, secure encryption)

# Certificate for UI domain (e.g., canary-aws.zipline.ai)
resource "aws_acm_certificate" "ui_cert" {
  count = var.ui_domain != "" ? 1 : 0

  domain_name       = var.ui_domain
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
  count = var.hub_domain != "" ? 1 : 0

  domain_name       = var.hub_domain
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
  count = var.fetcher_domain != "" ? 1 : 0

  domain_name       = var.fetcher_domain
  validation_method = "DNS"

  tags = {
    Name = "${var.name_prefix}-fetcher-cert"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Output the DNS validation records needed
# You'll need to add these CNAME records to your DNS provider to validate the certificates
output "ui_cert_validation_records" {
  description = "DNS records to add for UI certificate validation"
  value = var.ui_domain != "" ? [
    for dvo in aws_acm_certificate.ui_cert[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

output "hub_cert_validation_records" {
  description = "DNS records to add for Hub certificate validation"
  value = var.hub_domain != "" ? [
    for dvo in aws_acm_certificate.hub_cert[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

output "fetcher_cert_validation_records" {
  description = "DNS records to add for Fetcher certificate validation"
  value = var.fetcher_domain != "" ? [
    for dvo in aws_acm_certificate.fetcher_cert[0].domain_validation_options : {
      name  = dvo.resource_record_name
      type  = dvo.resource_record_type
      value = dvo.resource_record_value
    }
  ] : []
}

# Output the certificate ARNs (needed by the load balancer)
output "ui_cert_arn" {
  description = "ARN of the UI certificate"
  value       = var.ui_domain != "" ? aws_acm_certificate.ui_cert[0].arn : ""
}

output "hub_cert_arn" {
  description = "ARN of the Hub certificate"
  value       = var.hub_domain != "" ? aws_acm_certificate.hub_cert[0].arn : ""
}

output "fetcher_cert_arn" {
  description = "ARN of the Fetcher certificate"
  value       = var.fetcher_domain != "" ? aws_acm_certificate.fetcher_cert[0].arn : ""
}
