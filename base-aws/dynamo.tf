resource "aws_dynamodb_table" "chronon_metadata" {
  name           = "CHRONON_METADATA"
  read_capacity  = 10
  write_capacity = 10
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
  name           = "TABLE_PARTITIONS"
  read_capacity  = 10
  write_capacity = 10
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