locals {
  # ArgoCD
  argocd_namespace = "argocd"
  gitops_repo      = "https://github.com/Darbuki/namiviewk8s.git"
  charts_repo      = "https://github.com/Darbuki/namiview-charts.git"
  k8s_server       = "https://kubernetes.default.svc"


  # Karpenter
  karpenter_namespace = "karpenter"
  karpenter_version   = "1.4.0"
  karpenter_node_role = "KarpenterNodeRole-${var.cluster_name}"

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
