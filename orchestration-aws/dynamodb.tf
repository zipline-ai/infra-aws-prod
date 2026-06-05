module "dynamodb_tables" {
  source = "./modules/dynamodb-tables"

  table_prefix    = var.dynamodb_table_prefix
  read_capacity   = var.dynamodb_read_capacity
  write_capacity  = var.dynamodb_write_capacity
  replica_regions = var.dynamodb_replica_regions

  encrypt_at_rest         = var.encrypt_at_rest
  encryption_kms_key_arn  = var.encryption_kms_key_arn
  encryption_kms_key_arns = var.encryption_kms_key_arns
}
