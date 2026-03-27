# DynamoDB Tables Module

This module creates the DynamoDB tables required for Chronon metadata storage.

## Tables Created

1. **CHRONON_METADATA** (or `{prefix}CHRONON_METADATA` if prefix is set)
2. **TABLE_PARTITIONS** (or `{prefix}TABLE_PARTITIONS` if prefix is set)

Both tables are configured with:
- Binary hash key: `keyBytes`
- TTL enabled on attribute: `ttl`
- Configurable read/write capacity units

## Usage

```hcl
module "dynamodb_tables" {
  source = "./modules/dynamodb-tables"

  table_prefix   = "mycompany"  # Optional: results in "mycompany_CHRONON_METADATA"
  read_capacity  = 10           # Optional: defaults to 10
  write_capacity = 10           # Optional: defaults to 10
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| table_prefix | Prefix to prepend to DynamoDB table names. If empty, no prefix is added. | `string` | `""` | no |
| read_capacity | Read capacity units for DynamoDB tables | `number` | `10` | no |
| write_capacity | Write capacity units for DynamoDB tables | `number` | `10` | no |

## Outputs

| Name | Description |
|------|-------------|
| chronon_metadata_table_name | Name of the Chronon metadata DynamoDB table |
| chronon_metadata_table_arn | ARN of the Chronon metadata DynamoDB table |
| table_partitions_table_name | Name of the table partitions DynamoDB table |
| table_partitions_table_arn | ARN of the table partitions DynamoDB table |
