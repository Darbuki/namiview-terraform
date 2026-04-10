locals {
  common_tags = {
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }

  public_subnet_tags = merge(local.common_tags, {
    "kubernetes.io/role/elb" = 1
  })

  private_subnet_tags = merge(local.common_tags, {
    "kubernetes.io/role/internal-elb" = 1
    "karpenter.sh/discovery"          = var.cluster_name
  })
}
