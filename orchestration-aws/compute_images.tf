locals {
  spark_compute_image_registry = trimsuffix(trimspace(var.spark_compute_image_registry), "/")

  # 3.5 is the version chronon is built and tested against. Kumar's UC +
  # patched delta-spark jars (chronon#1898 etc.) are baked into the 3.5
  # lineage via crucible#23; the 4.1 lineage doesn't have them. Keep both
  # spark and history server on the same major.
  default_spark_compute_image = local.spark_compute_image_registry != "" ? "${local.spark_compute_image_registry}/ziplineai/spark:3.5-crucible-latest" : "ziplineai/spark:3.5-crucible-latest"

  spark_compute_image_override = try(trimspace(var.spark_compute_image), "")

  spark_compute_image        = local.spark_compute_image_override != "" ? local.spark_compute_image_override : local.default_spark_compute_image
  spark_history_server_image = local.spark_compute_image
}
