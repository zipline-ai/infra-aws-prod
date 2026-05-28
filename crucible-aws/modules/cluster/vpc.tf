###############################################################################
# Reuse the customer's Zipline VPC and subnets. The larger Zipline stack passes
# IDs directly; standalone installs can discover the same network by Name tags.
###############################################################################

data "aws_vpc" "shared" {
  count = var.shared_vpc_id == "" ? 1 : 0

  filter {
    name   = "tag:Name"
    values = [var.shared_vpc_name_tag]
  }
}

data "aws_subnet" "shared" {
  for_each = length(var.shared_subnet_ids) == 0 ? toset(var.shared_subnet_name_tags) : toset([])

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
  # Pin to the selected VPC so a name collision with another VPC's subnet
  # tags can't bind the cluster to the wrong network.
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

data "aws_subnet" "ingress_nlb" {
  for_each = length(var.ingress_nlb_subnet_ids) == 0 ? toset(var.ingress_nlb_subnet_name_tags) : toset([])

  filter {
    name   = "tag:Name"
    values = [each.value]
  }
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  vpc_id                 = var.shared_vpc_id != "" ? var.shared_vpc_id : data.aws_vpc.shared[0].id
  subnet_ids             = length(var.shared_subnet_ids) > 0 ? var.shared_subnet_ids : [for s in data.aws_subnet.shared : s.id]
  ingress_nlb_subnet_ids = length(var.ingress_nlb_subnet_ids) > 0 ? var.ingress_nlb_subnet_ids : [for s in data.aws_subnet.ingress_nlb : s.id]
}
