resource "aws_dynamodb_table" "chronon_metadata" {
  name           = "CHRONON_METADATA_${upper(var.customer_name)}"
  billing_mode   = "PROVISIONED"
  read_capacity  = var.dynamo_read_capacity
  write_capacity = var.dynamo_write_capacity
  hash_key       = "keyBytes"

  attribute {
    name = "keyBytes"
    type = "B"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name = "CHRONON_METADATA_${var.customer_name}"
  }
}
