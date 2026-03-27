module "dynamodb_tables" {
  source = "./modules/dynamodb-tables"

  table_prefix   = var.dynamodb_table_prefix
  read_capacity  = var.dynamodb_read_capacity
  write_capacity = var.dynamodb_write_capacity
}