module "orchestration" {
  source = "../orchestration-aws"

  name_prefix = var.customer_name
  artifact_prefix = var.artifact_prefix
  main_subnet_id = aws_subnet.main.id
  secondary_subnet_id = aws_subnet.secondary.id
  security_group_id = aws_security_group.emr_sg.id
  dockerhub_token = var.dockerhub_token
}