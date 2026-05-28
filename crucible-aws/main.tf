module "cluster" {
  source = "./modules/cluster"

  region       = var.region
  cluster_name = var.cluster_name
  eks_version  = var.eks_version

  shared_vpc_id                = var.shared_vpc_id
  shared_vpc_name_tag          = var.shared_vpc_name_tag
  shared_subnet_ids            = var.shared_subnet_ids
  shared_subnet_name_tags      = var.shared_subnet_name_tags
  ingress_nlb_subnet_ids       = var.ingress_nlb_subnet_ids
  ingress_nlb_subnet_name_tags = var.ingress_nlb_subnet_name_tags

  node_instance_types         = var.node_instance_types
  node_min_size               = var.node_min_size
  node_max_size               = var.node_max_size
  node_desired_size           = var.node_desired_size
  control_node_instance_types = var.control_node_instance_types
  control_node_min_size       = var.control_node_min_size
  control_node_max_size       = var.control_node_max_size
  control_node_desired_size   = var.control_node_desired_size

  personnel_arns            = var.personnel_arns
  crucible_bucket_name      = var.crucible_bucket_name
  public_host               = var.public_host
  eks_public_access_cidrs   = var.eks_public_access_cidrs
  chronon_artifact_buckets  = var.chronon_artifact_buckets
  chronon_warehouse_buckets = var.chronon_warehouse_buckets
}

module "ingress_nginx" {
  source = "./modules/ingress-nginx"

  acm_certificate_arn    = module.cluster.acm_certificate_arn
  ingress_nlb_subnet_ids = module.cluster.ingress_nlb_subnet_ids

  depends_on = [module.cluster]
}
