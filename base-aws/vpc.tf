// Establishes the network for the kubernetes cluster
resource "aws_vpc" "main" {
  count                = var.existing_vpc_id != "" ? 0 : 1
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "zipline-${var.customer_name}-vpc"
  }
}

resource "aws_subnet" "main" {
  count                   = var.existing_vpc_id != "" ? 0 : 1
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "172.31.0.0/20"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"
  tags = {
    Name                              = "zipline-${var.customer_name}-subnet-main"
    "kubernetes.io/role/elb"          = "1" # Allows internet-facing load balancers
    "kubernetes.io/role/internal-elb" = "1" # Allows internal load balancers
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_subnet" "secondary" {
  count                   = var.existing_vpc_id != "" ? 0 : 1
  vpc_id                  = aws_vpc.main[0].id
  cidr_block              = "172.31.16.0/20"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}b"
  tags = {
    Name                              = "zipline-${var.customer_name}-subnet-secondary"
    "kubernetes.io/role/elb"          = "1" # Allows internet-facing load balancers
    "kubernetes.io/role/internal-elb" = "1" # Allows internal load balancers
  }
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "emr_sg" {
  name        = "zipline-${var.customer_name}-sg"
  description = "Security group for Zipline"
  vpc_id      = var.existing_vpc_id != "" ? var.existing_vpc_id : aws_vpc.main[0].id

  lifecycle {
    prevent_destroy = true
  }
}

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


resource "aws_vpc_security_group_egress_rule" "allow_access" {
  security_group_id = aws_security_group.emr_sg.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_internet_gateway" "gw" {
  count = var.existing_vpc_id != "" ? 0 : 1
  vpc_id = aws_vpc.main[0].id
}

resource "aws_route_table" "r" {
  count = var.existing_vpc_id != "" ? 0 : 1
  vpc_id = aws_vpc.main[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw[0].id
  }
}

resource "aws_main_route_table_association" "a" {
  count           = var.existing_vpc_id != "" ? 0 : 1
  vpc_id         = aws_vpc.main[0].id
  route_table_id = aws_route_table.r[0].id
}

# Gateway VPC endpoints for EMR Serverless (workers don't get public IPs)
resource "aws_vpc_endpoint" "s3" {
  count             = var.existing_vpc_id != "" ? 0 : 1
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.r[0].id]
}

resource "aws_vpc_endpoint" "dynamodb" {
  count             = var.existing_vpc_id != "" ? 0 : 1
  vpc_id            = aws_vpc.main[0].id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.r[0].id]
}

output "primary_subnet_id" {
  value = var.existing_vpc_id != "" ? var.existing_vpc_primary_subnet_id : aws_subnet.main[0].id
}

output "secondary_subnet_id" {
  value = var.existing_vpc_id != "" ? var.existing_vpc_secondary_subnet_id : aws_subnet.secondary[0].id
}