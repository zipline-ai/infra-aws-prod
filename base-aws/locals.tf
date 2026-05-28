locals {
  # Used ONLY for globally-unique AWS resource names (S3 buckets).
  # Account-scoped resources (IAM, DynamoDB, Secrets Manager, EKS, EMR, CloudWatch,
  # Glue, AMP, etc.) are isolated by AWS account and keep var.customer_name as-is.
  global_resource_qualifier = var.environment != "" ? "${var.environment}-${var.customer_name}" : var.customer_name
}
