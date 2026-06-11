locals {
  spark_compute_image_registry = trimsuffix(trimspace(var.spark_compute_image_registry), "/")

  # ziplineai/spark:latest is the no-bake generic image (chronon#1919) — chronon jar
  # is pulled at submit time via spark-submit's S3A URL, not baked into the image.
  # Tag tracks `latest` to match the zipline_version convention used by hub/ui/eval.
  default_spark_compute_image = local.spark_compute_image_registry != "" ? "${local.spark_compute_image_registry}/ziplineai/spark:latest" : "ziplineai/spark:latest"

  spark_compute_image_override = try(trimspace(var.spark_compute_image), "")

  spark_compute_image        = local.spark_compute_image_override != "" ? local.spark_compute_image_override : local.default_spark_compute_image
  spark_history_server_image = local.spark_compute_image
}
