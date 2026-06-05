resource "aws_db_subnet_group" "zipline" {
  name        = "${var.name_prefix}-zipline-subnet-group"
  subnet_ids  = [var.main_subnet_id, var.secondary_subnet_id] # Replace with your subnet IDs
  description = "A subnet group for the Zipline RDS instance"
}

# Generate a random password for the RDS instance
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store credentials in Secrets Manager with a readable name
resource "aws_secretsmanager_secret" "db_credentials" {
  name        = "${var.name_prefix}-zipline-db-password"
  description = "Database credentials for Zipline orchestration RDS instance"
  kms_key_id  = var.encryption_kms_key_arn != "" ? var.encryption_kms_key_arn : null
}

resource "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "locker_user"
    password = random_password.db_password.result
  })
}

resource "aws_db_instance" "zipline" {
  identifier        = "${var.name_prefix}-zipline-orch-instance"
  engine            = "postgres"
  instance_class    = "db.t3.medium"
  allocated_storage = 20
  db_name           = "execution_info"
  username          = "locker_user"
  password          = random_password.db_password.result

  storage_encrypted = var.encrypt_at_rest
  kms_key_id        = var.encrypt_at_rest && var.encryption_kms_key_arn != "" ? var.encryption_kms_key_arn : null

  db_subnet_group_name   = aws_db_subnet_group.zipline.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false
  multi_az               = true
}

resource "aws_iam_policy" "rds_secret_policy" {
  # Prefixed so a second deployment in the same AWS account doesn't collide
  # with the existing canary's policy (IAM policy names are account-scoped).
  name        = "${var.name_prefix}-rds-secret-read"
  description = "Allows reading the database credentials from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = [aws_secretsmanager_secret.db_credentials.arn]
      }
    ]
  })
}

# Policy attachments will be added for EKS service accounts via IRSA
