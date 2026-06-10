locals {
  chronon_metadata_base_name = "CHRONON_METADATA"
  table_partitions_base_name = "TABLE_PARTITIONS"
  default_kms_key_arn        = var.encryption_kms_key_arn != "" ? var.encryption_kms_key_arn : null
  enhanced_stats_base_name   = "ENHANCED_STATS"
  data_quality_batch_name    = "DATA_QUALITY_METRICS_BATCH"
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

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.default_kms_key_arn
  }

  # Global Tables v2 requires streams enabled on the source table
  stream_enabled   = length(compact(var.replica_regions)) > 0 ? true : false
  stream_view_type = length(compact(var.replica_regions)) > 0 ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = toset(compact(var.replica_regions))
    content {
      region_name = replica.value
      kms_key_arn = lookup(var.encryption_kms_key_arns, replica.value, local.default_kms_key_arn)
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

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.default_kms_key_arn
  }
}

resource "aws_dynamodb_table" "enhanced_stats" {
  name         = "${var.table_prefix}${local.enhanced_stats_base_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "keyBytes"
    type = "B"
  }

  attribute {
    name = "ts"
    type = "N"
  }

  hash_key  = "keyBytes"
  range_key = "ts"

  ttl {
    attribute_name = "ttl"
    enabled        = false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.default_kms_key_arn
  }

  # Global Tables v2 requires streams enabled on the source table
  stream_enabled   = length(compact(var.replica_regions)) > 0 ? true : false
  stream_view_type = length(compact(var.replica_regions)) > 0 ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = toset(compact(var.replica_regions))
    content {
      region_name = replica.value
      kms_key_arn = lookup(var.encryption_kms_key_arns, replica.value, local.default_kms_key_arn)
    }
  }
}

resource "aws_dynamodb_table" "data_quality_metrics_batch" {
  name         = "${var.table_prefix}${local.data_quality_batch_name}"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "keyBytes"
    type = "B"
  }

  attribute {
    name = "ts"
    type = "N"
  }

  hash_key  = "keyBytes"
  range_key = "ts"

  ttl {
    attribute_name = "ttl"
    enabled        = false
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = local.default_kms_key_arn
  }

  # Global Tables v2 requires streams enabled on the source table
  stream_enabled   = length(compact(var.replica_regions)) > 0 ? true : false
  stream_view_type = length(compact(var.replica_regions)) > 0 ? "NEW_AND_OLD_IMAGES" : null

  dynamic "replica" {
    for_each = toset(compact(var.replica_regions))
    content {
      region_name = replica.value
      kms_key_arn = lookup(var.encryption_kms_key_arns, replica.value, local.default_kms_key_arn)
    }
  }
}
