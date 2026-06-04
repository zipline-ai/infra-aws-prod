variable "table_prefix" {
  type        = string
  description = "Prefix to prepend to DynamoDB table names. If empty, no prefix is added."
  default     = ""
}

variable "read_capacity" {
  type        = number
  description = "Read capacity units for DynamoDB tables"
  default     = 10
}

variable "write_capacity" {
  type        = number
  description = "Write capacity units for DynamoDB tables"
  default     = 10
}

variable "replica_regions" {
  type        = list(string)
  description = "Additional AWS regions to replicate these DynamoDB tables to using Global Tables v2. Empty disables replication."
  default     = []
}

variable "encryption_kms_key_arn" {
  type        = string
  description = "Optional customer managed KMS key ARN to use for DynamoDB at-rest encryption. Leave empty to use the default AWS managed service key."
  default     = ""

  validation {
    condition = (
      length(compact(var.replica_regions)) == 0 ||
      (
        var.encryption_kms_key_arn != "" &&
        (
          can(regex(":key/mrk-", var.encryption_kms_key_arn)) ||
          alltrue([for region in compact(var.replica_regions) : contains(keys(var.encryption_kms_key_arns), region)])
        )
      )
    )
    error_message = "When replica_regions is non-empty, encryption_kms_key_arn must be a multi-Region KMS key ARN, or encryption_kms_key_arns must include a region-specific key ARN for every replica region."
  }
}

variable "encryption_kms_key_arns" {
  type        = map(string)
  description = "Optional customer managed KMS key ARNs keyed by DynamoDB replica region. Use this when replica regions need region-specific keys."
  default     = {}
}
