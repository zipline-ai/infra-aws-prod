###############################################################################
# ACM certificate for the crucible-aws.zipline.ai surface.
#
# The cert is attached to the nginx-ingress NLB (see nginx.tf), which terminates
# TLS for every Ingress on this cluster. One cert with SANs covers the apex
# host plus the spark-history subdomain.
#
# DNS validation: ACM emits one CNAME per domain into the cert's
# `domain_validation_options`. Add those to Cloudflare (as DNS-only records).
# `aws_acm_certificate_validation` then waits for ACM to confirm.
#
# Spark History Server is path-prefixed under the main host
# (`crucible-aws.zipline.ai/spark-history`), so no SAN is needed for it.
###############################################################################

resource "aws_acm_certificate" "crucible_aws" {
  domain_name       = var.public_host
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "crucible-aws-tls"
  }
}

resource "aws_acm_certificate_validation" "crucible_aws" {
  certificate_arn = aws_acm_certificate.crucible_aws.arn

  # No `validation_record_fqdns` — that's needed only when terraform manages
  # the DNS provider. We use Cloudflare out-of-band, so this just waits for
  # whatever validation records you've added there.
  timeouts {
    create = "30m"
  }
}
