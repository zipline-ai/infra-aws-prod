# Outputs for base AWS infrastructure

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "subnet_ids" {
  description = "List of subnet IDs"
  value       = [aws_subnet.main.id, aws_subnet.secondary.id]
}

output "main_subnet_id" {
  description = "ID of the primary subnet"
  value       = aws_subnet.main.id
}

output "secondary_subnet_id" {
  description = "ID of the secondary subnet"
  value       = aws_subnet.secondary.id
}

output "emr_security_group_id" {
  description = "ID of the EMR security group"
  value       = aws_security_group.emr_sg.id
}

output "warehouse_bucket_name" {
  description = "Name of the S3 warehouse bucket"
  value       = aws_s3_bucket.warehouse.bucket
}

output "warehouse_bucket_arn" {
  description = "ARN of the S3 warehouse bucket"
  value       = aws_s3_bucket.warehouse.arn
}

output "logs_bucket_name" {
  description = "Name of the S3 logs bucket"
  value       = aws_s3_bucket.logs.bucket
}

output "logs_bucket_arn" {
  description = "ARN of the S3 logs bucket"
  value       = aws_s3_bucket.logs.arn
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB metadata table"
  value       = aws_dynamodb_table.chronon_metadata.name
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB metadata table"
  value       = aws_dynamodb_table.chronon_metadata.arn
}

output "emr_cluster_id" {
  description = "ID of the EMR cluster"
  value       = aws_emr_cluster.main.id
}

output "emr_cluster_name" {
  description = "Name of the EMR cluster"
  value       = aws_emr_cluster.main.name
}

output "emr_master_public_dns" {
  description = "Public DNS of the EMR master node"
  value       = aws_emr_cluster.main.master_public_dns
}

output "emr_profile_role_arn" {
  description = "ARN of the EMR EC2 instance profile role"
  value       = aws_iam_role.emr_profile_role.arn
}

output "emr_service_role_arn" {
  description = "ARN of the EMR service role"
  value       = aws_iam_role.emr_service_role.arn
}
