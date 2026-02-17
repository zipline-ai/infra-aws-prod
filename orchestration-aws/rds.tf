resource "aws_db_subnet_group" "zipline" {
  name       = "${var.name_prefix}-zipline-subnet-group"
  subnet_ids = [var.main_subnet_id, var.secondary_subnet_id] # Replace with your subnet IDs
  description = "A subnet group for the Zipline RDS instance"
}

resource "aws_db_instance" "zipline" {
  identifier              = "${var.name_prefix}-zipline-orch-instance"
  engine                  = "postgres"
  instance_class          = "db.t3.medium"
  allocated_storage       = 20
  db_name                 = "execution_info"
  username                = "locker_user"
  manage_master_user_password = true

  db_subnet_group_name    = aws_db_subnet_group.zipline.name
  vpc_security_group_ids  = [var.security_group_id]
  skip_final_snapshot     = true
  publicly_accessible     = false
  multi_az                = true
}

resource "aws_iam_policy" "rds_secret_policy" {
  name        = "RDSSecretReadAccess"
  description = "Allows reading the managed RDS master password from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        # We point directly to the ARN exported by the RDS instance
        Resource = [aws_db_instance.zipline.master_user_secret[0].secret_arn]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app_access_role_access" {
  role       = aws_iam_role.apprunner_access_role.name
  policy_arn = aws_iam_policy.rds_secret_policy.arn
}

resource "aws_iam_role_policy_attachment" "app_instance_role_access" {
  role       = aws_iam_role.apprunner_instance_role.name
  policy_arn = aws_iam_policy.rds_secret_policy.arn
}
