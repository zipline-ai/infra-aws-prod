###############################################################################
# ACM certificate for the customer-provided Crucible public host.
#
# The cert is attached to the nginx-ingress NLB (see nginx.tf), which terminates
# TLS for every Ingress on this cluster.
#
# DNS validation: ACM emits one CNAME per domain into the cert's
# `domain_validation_options`. Add those records to your DNS provider.
# `aws_acm_certificate_validation` then waits for ACM to confirm.
#
# Spark History Server is path-prefixed under the main host, so no SAN is
# needed for it.
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
  # the DNS provider. This waits for whatever validation records you've added.
  timeouts {
    create = "30m"
  }
}
