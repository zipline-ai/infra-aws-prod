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
