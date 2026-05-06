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

  # DynamoDB Configuration
  dynamodb_table_prefix    = var.dynamodb_table_prefix
  dynamodb_read_capacity   = var.dynamodb_read_capacity
  dynamodb_write_capacity  = var.dynamodb_write_capacity
  dynamodb_replica_regions = var.dynamodb_replica_regions

  # Custom domains for HTTPS
  ui_domain        = var.ui_domain
  hub_domain       = var.hub_domain
  hub_external_url = var.hub_external_url
  fetcher_domain   = var.fetcher_domain
  eval_domain      = var.eval_domain

  # EKS Configuration
  eks_version      = var.eks_version
  fetcher_replicas = var.fetcher_replicas

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

  additional_flink_s3_buckets = var.additional_flink_s3_buckets
  additional_data_buckets     = var.additional_data_buckets

  zipline_auth_enabled                = var.zipline_auth_enabled
  google_oauth_client_id              = var.google_oauth_client_id
  google_oauth_client_secret          = var.google_oauth_client_secret
  github_oauth_client_id              = var.github_oauth_client_id
  github_oauth_client_secret          = var.github_oauth_client_secret
  microsoft_entra_tenant_id           = var.microsoft_entra_tenant_id
  microsoft_entra_oauth_client_id     = var.microsoft_entra_oauth_client_id
  microsoft_entra_oauth_client_secret = var.microsoft_entra_oauth_client_secret
  sso_provider_id                     = var.sso_provider_id
  sso_domain                          = var.sso_domain
  sso_issuer                          = var.sso_issuer
  sso_client_id                       = var.sso_client_id
  sso_client_secret                   = var.sso_client_secret
  idp_role_mapping                    = var.idp_role_mapping
  idp_group_claim                     = var.idp_group_claim
}
