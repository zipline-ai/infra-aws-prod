resource "aws_s3_bucket" "zipline_warehouse_bucket" {
  bucket = "zipline-warehouse-${lower(var.customer_name)}"
}

output "aws_s3_bucket_arn" {
  value = aws_s3_bucket.zipline_warehouse_bucket.arn
}