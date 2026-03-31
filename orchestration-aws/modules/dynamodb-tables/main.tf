locals {
  chronon_metadata_base_name  = "CHRONON_METADATA"
  table_partitions_base_name  = "TABLE_PARTITIONS"
}

resource "aws_dynamodb_table" "chronon_metadata" {
  name           = "${var.table_prefix}${local.chronon_metadata_base_name}"
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
  name           = "${var.table_prefix}${local.table_partitions_base_name}"
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
