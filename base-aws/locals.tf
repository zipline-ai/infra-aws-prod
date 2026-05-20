locals {
  customer_name = var.environment != "" ? "${var.environment}-${var.customer_name}" : var.customer_name
}
