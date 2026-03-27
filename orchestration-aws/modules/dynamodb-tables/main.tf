resource "aws_dynamodb_table" "chronon_metadata" {
  name           = "${var.table_prefix}CHRONON_METADATA"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity

  attribute {
    name = "keyBytes"
    type = "B"
  }

  hash_key = "keyBytes"

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}

resource "aws_dynamodb_table" "table_partitions" {
  name           = "${var.table_prefix}TABLE_PARTITIONS"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity

  attribute {
    name = "keyBytes"
    type = "B"
  }

  hash_key = "keyBytes"

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
