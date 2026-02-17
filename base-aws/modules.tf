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
  ui_domain  = var.ui_domain
  hub_domain = var.hub_domain

  # Personnel access
  personnel_arns = var.personnel_arns
}
