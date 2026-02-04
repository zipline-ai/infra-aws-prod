# VPC and networking infrastructure for Zipline

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "zipline-${var.customer_name}-vpc"
  }
}

resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[0]
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = {
    Name = "zipline-${var.customer_name}-subnet-main"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "secondary" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidrs[1]
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"
  tags = {
    Name = "zipline-${var.customer_name}-subnet-secondary"
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "emr_sg" {
  name        = "zipline-${var.customer_name}-sg"
  description = "Security group for Zipline EMR cluster"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "zipline-${var.customer_name}-sg"
  }
}

# Allow SSH from EC2 Instance Connect (for debugging)
data "aws_ec2_managed_prefix_list" "ec2_instance_connect" {
  filter {
    name   = "prefix-list-name"
    values = ["com.amazonaws.${var.region}.ec2-instance-connect"]
  }
}

resource "aws_vpc_security_group_ingress_rule" "instance_connect" {
  security_group_id = aws_security_group.emr_sg.id
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  prefix_list_id    = data.aws_ec2_managed_prefix_list.ec2_instance_connect.id
}

# Allow intra-VPC traffic for EMR cluster communication
resource "aws_vpc_security_group_ingress_rule" "intra_vpc" {
  security_group_id            = aws_security_group.emr_sg.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.emr_sg.id
}

# Egress to VPC endpoints and AWS services (via VPC endpoints)
resource "aws_vpc_security_group_egress_rule" "https_vpc_endpoints" {
  security_group_id = aws_security_group.emr_sg.id
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = var.vpc_cidr
  description       = "HTTPS access to VPC endpoints"
}

# Egress for intra-cluster communication
resource "aws_vpc_security_group_egress_rule" "intra_vpc" {
  security_group_id            = aws_security_group.emr_sg.id
  ip_protocol                  = "-1"
  referenced_security_group_id = aws_security_group.emr_sg.id
  description                  = "Intra-cluster communication"
}

# Internet Gateway (required for EMR bootstrapping and package downloads)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "zipline-${var.customer_name}-igw"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "zipline-${var.customer_name}-rt"
  }
}

resource "aws_main_route_table_association" "main" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.main.id
}

# VPC Endpoints for private AWS service access
# These provide private connectivity without traversing the public internet

# S3 Gateway Endpoint (free, uses route table)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.main.id]

  tags = {
    Name = "zipline-${var.customer_name}-s3-endpoint"
  }
}

# DynamoDB Gateway Endpoint (free, uses route table)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.main.id]

  tags = {
    Name = "zipline-${var.customer_name}-dynamodb-endpoint"
  }
}

# Security group for interface endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "zipline-${var.customer_name}-vpc-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "HTTPS from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "zipline-${var.customer_name}-vpc-endpoints-sg"
  }
}

# Glue Interface Endpoint (for Glue Data Catalog access)
resource "aws_vpc_endpoint" "glue" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.glue"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id, aws_subnet.secondary.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "zipline-${var.customer_name}-glue-endpoint"
  }
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id, aws_subnet.secondary.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "zipline-${var.customer_name}-logs-endpoint"
  }
}

# EMR Interface Endpoint
resource "aws_vpc_endpoint" "emr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.elasticmapreduce"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id, aws_subnet.secondary.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "zipline-${var.customer_name}-emr-endpoint"
  }
}

# STS Interface Endpoint (for IAM role assumption)
resource "aws_vpc_endpoint" "sts" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.sts"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.main.id, aws_subnet.secondary.id]
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "zipline-${var.customer_name}-sts-endpoint"
  }
}
