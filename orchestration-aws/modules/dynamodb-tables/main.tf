locals {
  chronon_metadata_base_name  = "CHRONON_METADATA"
  table_partitions_base_name  = "TABLE_PARTITIONS"
}

resource "aws_dynamodb_table" "chronon_metadata" {
  name         = "${var.table_prefix}${local.chronon_metadata_base_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "keyBytes"
    type = "B"
  }

  hash_key = "keyBytes"

  ttl {
    attribute_name = "ttl"
    enabled        = false
  }

  # Global Tables v2 requires streams enabled on the source table
  stream_enabled   = length(compact(var.replica_regions)) > 0 ? true : false
  stream_view_type = length(compact(var.replica_regions)) > 0 ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = toset(compact(var.replica_regions))
    content {
      region_name = replica.value
    }
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
    enabled        = false
  }
}
