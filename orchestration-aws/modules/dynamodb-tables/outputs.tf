output "chronon_metadata_table_name" {
  description = "Name of the Chronon metadata DynamoDB table"
  value       = aws_dynamodb_table.chronon_metadata.name
}

output "chronon_metadata_table_arn" {
  description = "ARN of the Chronon metadata DynamoDB table"
  value       = aws_dynamodb_table.chronon_metadata.arn
}

output "table_partitions_table_name" {
  description = "Name of the table partitions DynamoDB table"
  value       = aws_dynamodb_table.table_partitions.name
}

output "table_partitions_table_arn" {
  description = "ARN of the table partitions DynamoDB table"
  value       = aws_dynamodb_table.table_partitions.arn
}
