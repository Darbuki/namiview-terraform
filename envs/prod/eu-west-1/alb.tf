# ACM certificate for EKS services
resource "aws_acm_certificate" "eks" {
  domain_name               = "eks.namiview.com"
  subject_alternative_names = ["*.eks.namiview.com"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# IRSA role for AWS Load Balancer Controller
module "alb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${var.cluster_name}-alb-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}

# AWS Load Balancer Controller
resource "helm_release" "alb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.region
    vpcId       = module.vpc.vpc_id

    serviceAccount = {
      create = true
      name   = "aws-load-balancer-controller"
      annotations = {
        "eks.amazonaws.com/role-arn" = module.alb_controller_irsa.iam_role_arn
      }
    }
  })]

  depends_on = [module.eks]
}

# GitOps Bridge — passes AWS resource info into the cluster for ArgoCD to consume
resource "kubernetes_config_map" "gitops_bridge" {
  metadata {
    name      = "gitops-bridge"
    namespace = local.argocd_namespace
  }

  data = {
    acm_certificate_arn = aws_acm_certificate.eks.arn
    cluster_name        = var.cluster_name
    region              = var.region
    vpc_id              = module.vpc.vpc_id
    s3_bucket_name      = aws_s3_bucket.namiview-prod-bucket.bucket
    eso_irsa_role_arn   = module.eso_irsa.iam_role_arn
  }

  depends_on = [helm_release.argocd]
}
