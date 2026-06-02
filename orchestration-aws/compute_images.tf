locals {
  spark_compute_image_registry = trimsuffix(trimspace(var.spark_compute_image_registry), "/")

  default_spark_compute_image = local.spark_compute_image_registry != "" ? "${local.spark_compute_image_registry}/ziplineai/spark:4.1-crucible-latest" : "ziplineai/spark:4.1-crucible-latest"

  spark_compute_image_override = try(trimspace(var.spark_compute_image), "")

  spark_compute_image        = local.spark_compute_image_override != "" ? local.spark_compute_image_override : local.default_spark_compute_image
  spark_history_server_image = local.spark_compute_image
}
