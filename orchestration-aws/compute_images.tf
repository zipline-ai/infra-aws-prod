locals {
  spark_compute_image_registry = trimsuffix(trimspace(var.spark_compute_image_registry), "/")
  flink_compute_image          = try(trimspace(var.flink_compute_image), "")

  # ziplineai/spark:nightly is the no-bake generic image (chronon#1919) — chronon jar
  # is pulled at submit time via spark-submit's S3A URL, not baked into the image.
  # Tag tracks `nightly` (republished on every chronon main push). `:latest` only
  # exists after a chronon release; switch to it once release cadence stabilizes.
  default_spark_compute_image = local.spark_compute_image_registry != "" ? "${local.spark_compute_image_registry}/ziplineai/spark:nightly" : "ziplineai/spark:nightly"

  spark_compute_image_override = try(trimspace(var.spark_compute_image), "")

  spark_compute_image        = local.spark_compute_image_override != "" ? local.spark_compute_image_override : local.default_spark_compute_image
  spark_history_server_image = local.spark_compute_image
}
