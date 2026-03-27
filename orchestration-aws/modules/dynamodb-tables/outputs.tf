output "chronon_metadata_table_name" {
  description = "Full name of the Chronon metadata DynamoDB table (with prefix)"
  value       = aws_dynamodb_table.chronon_metadata.name
}

output "chronon_metadata_table_arn" {
  description = "ARN of the Chronon metadata DynamoDB table"
  value       = aws_dynamodb_table.chronon_metadata.arn
}

output "chronon_metadata_base_name" {
  description = "Base name of the Chronon metadata table (without prefix)"
  value       = local.chronon_metadata_base_name
}

output "table_partitions_table_name" {
  description = "Full name of the table partitions DynamoDB table (with prefix)"
  value       = aws_dynamodb_table.table_partitions.name
}

output "table_partitions_table_arn" {
  description = "ARN of the table partitions DynamoDB table"
  value       = aws_dynamodb_table.table_partitions.arn
}

output "table_partitions_base_name" {
  description = "Base name of the table partitions table (without prefix)"
  value       = local.table_partitions_base_name
}

output "table_prefix" {
  description = "The table prefix used for DynamoDB tables"
  value       = var.table_prefix
}
