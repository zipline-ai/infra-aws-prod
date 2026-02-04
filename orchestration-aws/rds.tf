# RDS PostgreSQL for Zipline Orchestration

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# DB Subnet Group
resource "aws_db_subnet_group" "orchestration" {
  name        = "zipline-${var.customer_name}-db-subnet"
  description = "Subnet group for Zipline orchestration database"
  subnet_ids  = var.subnet_ids

  tags = {
    Name = "zipline-${var.customer_name}-db-subnet"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "zipline-${var.customer_name}-rds-sg"
  description = "Security group for Zipline RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
    description     = "Allow PostgreSQL from EKS cluster"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zipline-${var.customer_name}-rds-sg"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "orchestration" {
  identifier = "zipline-${var.customer_name}-orchestration"

  engine               = "postgres"
  engine_version       = var.rds_engine_version
  instance_class       = var.rds_instance_class
  allocated_storage    = var.rds_allocated_storage
  max_allocated_storage = var.rds_allocated_storage * 2
  storage_type         = "gp3"
  storage_encrypted    = true

  db_name  = "execution_info"
  username = "locker_user"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.orchestration.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = var.rds_multi_az
  publicly_accessible    = false
  skip_final_snapshot    = false
  final_snapshot_identifier = "zipline-${var.customer_name}-final-snapshot"

  backup_retention_period = var.rds_backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  performance_insights_enabled = true
  monitoring_interval          = 60
  monitoring_role_arn          = aws_iam_role.rds_monitoring.arn

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  deletion_protection = true

  tags = {
    Name = "zipline-${var.customer_name}-orchestration"
  }
}

# IAM Role for RDS Enhanced Monitoring
data "aws_iam_policy_document" "rds_monitoring_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name               = "zipline-${var.customer_name}-rds-monitoring-role"
  assume_role_policy = data.aws_iam_policy_document.rds_monitoring_assume_role.json

  tags = {
    Name = "zipline-${var.customer_name}-rds-monitoring-role"
  }
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
