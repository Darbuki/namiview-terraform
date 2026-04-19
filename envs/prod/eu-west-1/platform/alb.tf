# ACM certificate for EKS services
resource "aws_acm_certificate" "eks" {
  domain_name               = "eks.namiview.com"
  subject_alternative_names = ["grafana-eks.namiview.com", "argocd-eks.namiview.com"]
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

# TODO: Replace predictable IRSA ARNs in ArgoCD values with a dynamic approach
# (e.g., GitOps Bridge ConfigMap, SSM Parameter Store, or CI-driven Terraform outputs)
# Currently, IRSA role ARNs follow the pattern: arn:aws:iam::<account>:role/<cluster_name>-<service>
