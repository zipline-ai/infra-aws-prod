module "orchestration" {
  source = "../orchestration-aws"

  name_prefix         = var.customer_name
  artifact_prefix     = var.artifact_prefix
  zipline_version     = var.zipline_version
  main_subnet_id      = aws_subnet.main.id
  secondary_subnet_id = aws_subnet.secondary.id
  security_group_id   = aws_security_group.emr_sg.id
  vpc_id              = aws_vpc.main.id
  dockerhub_token     = var.dockerhub_token
  warehouse_bucket    = aws_s3_bucket.zipline_warehouse_bucket.id
  dynamodb_table_name = aws_dynamodb_table.chronon_metadata.name

  # Custom domains for HTTPS
  ui_domain      = var.ui_domain
  hub_domain       = var.hub_domain
  hub_external_url = var.hub_external_url
  fetcher_domain = var.fetcher_domain
  eval_domain    = var.eval_domain

  # EKS Configuration
  eks_version = var.eks_version

  # Personnel access
  personnel_arns = var.personnel_arns

  # EMR Serverless
  emr_log_uri              = var.emr_log_uri != "" ? var.emr_log_uri : "s3://zipline-logs-${var.customer_name}/emr/"
  emr_cloudwatch_log_group = aws_cloudwatch_log_group.emr_logs.name

  # Glue Schema Registry (optional)
  glue_schema_registry_name = var.glue_schema_registry_name

  # Databricks Unity Catalog integration (optional)
  databricks_client_id     = var.databricks_client_id
  databricks_client_secret = var.databricks_client_secret

  msk_cluster_arn = var.msk_cluster_arn
}
