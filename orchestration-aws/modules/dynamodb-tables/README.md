# DynamoDB Tables Module

This module creates the DynamoDB tables required for Chronon metadata storage.

## Tables Created

1. **CHRONON_METADATA** (or `{prefix}CHRONON_METADATA` if prefix is set) — supports optional Global Tables v2 replication
2. **TABLE_PARTITIONS** (or `{prefix}TABLE_PARTITIONS` if prefix is set)

Both tables are configured with:
- Binary hash key: `keyBytes`
- TTL enabled on attribute: `ttl`

**CHRONON_METADATA** uses on-demand (pay-per-request) billing; the `read_capacity` and `write_capacity` variables do not apply to it. When `replica_regions` is non-empty, Streams are enabled (`NEW_AND_OLD_IMAGES`) and the table is replicated to the specified regions using Global Tables v2.

**TABLE_PARTITIONS** uses provisioned billing with configurable read/write capacity units.

## Usage

```hcl
module "dynamodb_tables" {
  source = "./modules/dynamodb-tables"

  table_prefix    = "mycompany_"  # Optional: results in "mycompany_CHRONON_METADATA"
  read_capacity   = 10            # Optional: defaults to 10
  write_capacity  = 10            # Optional: defaults to 10
  replica_regions = ["us-west-2", "eu-west-1"]  # Optional: omit or leave empty to disable replication

  # Optional: use a multi-Region key as the default, and override replica regions when needed.
  encryption_kms_key_arn = "arn:aws:kms:us-west-2:123456789012:key/mrk-00000000000000000000000000000000"
  encryption_kms_key_arns = {
    eu-west-1 = "arn:aws:kms:eu-west-1:123456789012:key/mrk-11111111111111111111111111111111"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| table_prefix | Prefix to prepend to DynamoDB table names. If empty, no prefix is added. | `string` | `""` | no |
| read_capacity | Read capacity units for DynamoDB tables | `number` | `10` | no |
| write_capacity | Write capacity units for DynamoDB tables | `number` | `10` | no |
| replica_regions | Additional AWS regions for Global Tables v2 replication on CHRONON_METADATA. Empty disables replication. | `list(string)` | `[]` | no |
| encryption_kms_key_arn | Optional customer managed KMS key ARN for DynamoDB at-rest encryption. If `replica_regions` is non-empty, this must be a multi-Region KMS key ARN unless every replica region has an entry in `encryption_kms_key_arns`. | `string` | `""` | no |
| encryption_kms_key_arns | Optional customer managed KMS key ARNs keyed by replica region for CHRONON_METADATA Global Tables replicas. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| chronon_metadata_table_name | Name of the Chronon metadata DynamoDB table |
| chronon_metadata_table_arn | ARN of the Chronon metadata DynamoDB table |
| table_partitions_table_name | Name of the table partitions DynamoDB table |
| table_partitions_table_arn | ARN of the table partitions DynamoDB table |
