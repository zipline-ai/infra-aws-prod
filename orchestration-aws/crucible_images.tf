locals {
  crucible_image_registry = trimsuffix(trimspace(var.crucible_image_registry), "/")

  default_crucible_spark_image          = local.crucible_image_registry != "" ? "${local.crucible_image_registry}/ziplineai/spark:4.1-crucible-latest" : "ziplineai/spark:4.1-crucible-latest"
  default_crucible_flink_image          = local.crucible_image_registry != "" ? "${local.crucible_image_registry}/ziplineai/flink:1.20.3" : "ziplineai/flink:1.20.3"
  default_crucible_history_server_image = local.crucible_image_registry != "" ? "${local.crucible_image_registry}/ziplineai/spark:4.1-crucible-latest" : "ziplineai/spark:4.1-crucible-latest"

  crucible_spark_image_override = try(trimspace(var.crucible_spark_image), "")
  crucible_flink_image_override = try(trimspace(var.crucible_flink_image), "")

  crucible_spark_image          = local.crucible_spark_image_override != "" ? local.crucible_spark_image_override : local.default_crucible_spark_image
  crucible_flink_image          = local.crucible_flink_image_override != "" ? local.crucible_flink_image_override : local.default_crucible_flink_image
  crucible_history_server_image = local.default_crucible_history_server_image
}
