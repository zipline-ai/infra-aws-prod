###############################################################################
# Reuse the canary VPC and subnets.
#
# crucible-eks shares the canary VPC per user direction — keeps networking
# costs flat and avoids a separate NAT gateway. Discovered by Name tag so
# this module doesn't depend on the canary terraform state.
###############################################################################

data "aws_vpc" "shared" {
  filter {
    name   = "tag:Name"
    values = [var.shared_vpc_name_tag]
  }
}

data "aws_subnet" "shared" {
  for_each = toset(var.shared_subnet_name_tags)
  filter {
    name   = "tag:Name"
    values = [each.value]
  }
  # Pin to the selected VPC so a name collision with another VPC's subnet
  # tags can't bind the cluster to the wrong network.
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
}

locals {
  subnet_ids = [for s in data.aws_subnet.shared : s.id]
}
