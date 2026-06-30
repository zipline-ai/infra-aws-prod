output "zipline_custom_domain_dns_setup" {
  description = "DNS setup instructions for shared or per-service custom domains. Null when no custom domains are configured."
  value       = module.base_setup.zipline_custom_domain_dns_setup
}
