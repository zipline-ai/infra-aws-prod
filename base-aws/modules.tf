module "orchestration" {
  source = "../orchestration-aws"

  name_prefix         = var.customer_name
  artifact_prefix     = var.artifact_prefix
  main_subnet_id      = aws_subnet.main.id
  secondary_subnet_id = aws_subnet.secondary.id
  security_group_id   = aws_security_group.emr_sg.id
  vpc_id              = aws_vpc.main.id
  dockerhub_token     = var.dockerhub_token
  warehouse_bucket    = aws_s3_bucket.zipline_warehouse_bucket.id
  dynamodb_table_name = aws_dynamodb_table.chronon_metadata.name

  # Custom domains for HTTPS
  ui_domain      = var.ui_domain
  hub_domain     = var.hub_domain
  fetcher_domain = var.fetcher_domain
  eval_domain    = var.eval_domain

  # Personnel access
  personnel_arns = var.personnel_arns

  # EMR Serverless
  emr_serverless_app_id             = aws_emrserverless_application.spark.id
  emr_serverless_execution_role_arn = aws_iam_role.emr_serverless_role.arn
  emr_log_uri                       = var.emr_log_uri

  # Databricks Unity Catalog integration (optional)
  databricks_client_id     = var.databricks_client_id
  databricks_client_secret = var.databricks_client_secret
}
