variable "acm_certificate_arn" {
  description = "ACM certificate ARN for TLS termination at the nginx ingress NLB."
  type        = string
}

variable "ingress_nlb_subnet_ids" {
  description = "Optional public subnet IDs where the internet-facing nginx ingress NLB should be provisioned."
  type        = list(string)
  default     = []
}
